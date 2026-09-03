import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../features/downloader/models/download_format.dart';
import '../../features/downloader/models/download_item.dart';
import '../../features/downloader/services/download_history_service.dart';
import '../../features/settings/services/settings_service.dart';

/// Intelligent file resolver that matches and self-heals media file paths on disk,
/// gracefully handling Unicode fullwidth substitutions (e.g. \uFF5C), yt-dlp sanitizations,
/// and moved files without crashing on OS-illegal path characters.
class FileResolver {
  FileResolver._();

  /// Normalizes a title or filename string for robust comparison,
  /// removing symbols, punctuation, fullwidth characters, and excess whitespace.
  static String normalize(String input) {
    // Preserve letters, numbers, and marks (vowels/diacritics) across all Unicode alphabets
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\p{M}]', unicode: true), '');
  }

  /// Checks whether a given path string contains illegal filesystem characters on Windows.
  static bool hasIllegalCharacters(String path) {
    if (!kIsWeb && Platform.isWindows) {
      // Allow drive letter e.g. "C:\"
      final checkPath =
          path.length >= 3 && path[1] == ':' ? path.substring(2) : path;
      return checkPath.contains(RegExp(r'[*?"<>|]'));
    }
    return false;
  }

  /// Safely checks if a directory exists on disk without throwing OS errno 123 for invalid names.
  static Future<bool> safeDirExists(String path) async {
    if (path.isEmpty || hasIllegalCharacters(path)) return false;
    try {
      return await Directory(path).exists();
    } catch (_) {
      return false;
    }
  }

  /// Safely checks if a file exists on disk without throwing OS errno 123 for invalid names.
  static Future<bool> safeFileExists(String path) async {
    if (path.isEmpty || hasIllegalCharacters(path)) return false;
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  /// Attempts to resolve the actual filesystem path of a [DownloadItem].
  ///
  /// 1. Checks if [item.filePath] exists directly.
  /// 2. If missing, searches the containing directory, playlist directory,
  ///    or base downloads folder for a file matching the title and format.
  /// 3. If found, self-heals the cached path in [DownloadHistoryService] and returns the path.
  /// 4. Returns `null` if the file truly cannot be found on disk.
  static Future<String?> resolveFile(DownloadItem item) async {
    // 1. Direct path check
    if (item.filePath.isNotEmpty) {
      if (await safeFileExists(item.filePath)) {
        return item.filePath;
      }
    }

    // 2. Gather candidate search directories
    final candidateDirs = <Directory>{};

    if (item.filePath.isNotEmpty) {
      final parentPath = p.dirname(item.filePath);
      if (await safeDirExists(parentPath)) {
        candidateDirs.add(Directory(parentPath));
      }
    }

    try {
      final baseDir = await SettingsService.instance.resolveDownloadDirectory();
      if (await safeDirExists(baseDir)) {
        final baseDirObj = Directory(baseDir);
        candidateDirs.add(baseDirObj);

        if (item.playlistName != null && item.playlistName!.trim().isNotEmpty) {
          final playlistName = item.playlistName!.trim();
          final sanitizedName = _sanitizeFolderName(playlistName);

          // 1. Primary candidate: Sanitized folder name created by resolveDestinationFolder / yt-dlp
          if (sanitizedName.isNotEmpty) {
            final sanitizedPath = p.join(baseDir, sanitizedName);
            if (await safeDirExists(sanitizedPath)) {
              candidateDirs.add(Directory(sanitizedPath));
            }
          }

          // 2. Secondary: Raw folder name if different and syntax is valid
          if (playlistName != sanitizedName &&
              !hasIllegalCharacters(playlistName)) {
            final rawPath = p.join(baseDir, playlistName);
            if (await safeDirExists(rawPath)) {
              candidateDirs.add(Directory(rawPath));
            }
          }

          // 3. Smart scan: If not found yet, check subdirectories matching normalized name
          final normTarget = normalize(playlistName);
          if (normTarget.isNotEmpty) {
            try {
              final subEntities =
                  await baseDirObj.list(followLinks: false).toList();
              for (final entity in subEntities) {
                if (entity is Directory) {
                  final folderBase = p.basename(entity.path);
                  if (normalize(folderBase) == normTarget) {
                    candidateDirs.add(entity);
                    break;
                  }
                }
              }
            } catch (_) {}
          }
        }

        // Also check Videos folder if it's a video or moved
        final videosPath = p.join(baseDir, 'Videos');
        if (await safeDirExists(videosPath)) {
          final videosDir = Directory(videosPath);
          candidateDirs.add(videosDir);

          if (item.playlistName != null &&
              item.playlistName!.trim().isNotEmpty) {
            final playlistName = item.playlistName!.trim();
            final sanitizedName = _sanitizeFolderName(playlistName);

            if (sanitizedName.isNotEmpty) {
              final sanitizedVidPath = p.join(videosPath, sanitizedName);
              if (await safeDirExists(sanitizedVidPath)) {
                candidateDirs.add(Directory(sanitizedVidPath));
              }
            }

            if (playlistName != sanitizedName &&
                !hasIllegalCharacters(playlistName)) {
              final rawVidPath = p.join(videosPath, playlistName);
              if (await safeDirExists(rawVidPath)) {
                candidateDirs.add(Directory(rawVidPath));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error gathering candidate directories for FileResolver: $e');
    }

    // 3. Match against files in candidate directories
    final expectedExt = item.format == DownloadFormat.mp3 ? '.mp3' : '.mp4';
    final targetNormTitle = normalize(item.title);
    final targetNormFile = item.filePath.isNotEmpty
        ? normalize(p.basenameWithoutExtension(item.filePath))
        : '';

    for (final dir in candidateDirs) {
      try {
        final entities = await dir.list(followLinks: false).toList();
        for (final entity in entities) {
          if (entity is! File) continue;

          final ext = p.extension(entity.path).toLowerCase();
          // Accept exact extension, or video alternatives like .mkv/.webm
          final isExtMatch = (ext == expectedExt) ||
              (item.format == DownloadFormat.mp4 &&
                  (ext == '.mkv' || ext == '.webm' || ext == '.mp4'));
          if (!isExtMatch) continue;

          final entityName = p.basenameWithoutExtension(entity.path);
          final entityNorm = normalize(entityName);

          // Exact normalized match against title or original filename
          if (entityNorm.isNotEmpty &&
              (entityNorm == targetNormTitle ||
                  (targetNormFile.isNotEmpty &&
                      entityNorm == targetNormFile))) {
            _healItemPath(item, entity.path);
            return entity.path;
          }

          // Substring match if one encompasses the other with high overlap
          if (entityNorm.length >= 10 && targetNormTitle.length >= 10) {
            if (entityNorm.contains(targetNormTitle) ||
                targetNormTitle.contains(entityNorm)) {
              _healItemPath(item, entity.path);
              return entity.path;
            }
          }
        }
      } catch (e) {
        debugPrint('Error scanning dir ${dir.path} in FileResolver: $e');
      }
    }

    return null;
  }

  /// Silently updates the cached item filePath in [DownloadHistoryService].
  static void _healItemPath(DownloadItem item, String realPath) {
    if (item.filePath != realPath) {
      debugPrint('FileResolver self-healed: "${item.title}" -> "$realPath"');
      DownloadHistoryService.instance.updateItemFilePath(item.id, realPath);
    }
  }

  static String _sanitizeFolderName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  }
}
