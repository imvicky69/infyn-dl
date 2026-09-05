import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/download_format.dart';
import '../models/download_item.dart';
import '../../settings/services/settings_service.dart';

/// Persistent cache & history manager for media downloads.
class DownloadHistoryService {
  static const String _cacheFileName = 'downloads_cache.json';

  static DownloadHistoryService? _instance;
  static DownloadHistoryService get instance =>
      _instance ??= DownloadHistoryService._();

  DownloadHistoryService._();

  final List<DownloadItem> _cachedItems = [];
  final Map<String, String> _playlistUrls = {};
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          _cachedItems.clear();
          for (final item in jsonList) {
            if (item is Map<String, dynamic>) {
              final parsed = DownloadItem.fromJson(item);
              _cachedItems.add(parsed);
              if (parsed.playlistName != null &&
                  parsed.playlistName!.isNotEmpty &&
                  parsed.playlistUrl != null &&
                  parsed.playlistUrl!.isNotEmpty) {
                _playlistUrls[parsed.playlistName!] = parsed.playlistUrl!;
              }
            }
          }
        }
      }

      // Load playlist URLs file
      final urlFile = await _getPlaylistUrlsFile();
      if (await urlFile.exists()) {
        final content = await urlFile.readAsString();
        if (content.isNotEmpty) {
          final Map<String, dynamic> map = jsonDecode(content);
          map.forEach((k, v) {
            if (v is String && v.isNotEmpty) {
              _playlistUrls[k] = v;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing DownloadHistoryService: $e');
    }
    _isInitialized = true;
  }

  Future<File> _getCacheFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File(p.join(docsDir.path, _cacheFileName));
  }

  Future<File> _getPlaylistUrlsFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File(p.join(docsDir.path, 'playlist_urls.json'));
  }

  Future<void> _persistToDisk() async {
    try {
      final file = await _getCacheFile();
      final jsonList = _cachedItems.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving download history: $e');
    }
  }

  Future<void> _persistPlaylistUrls() async {
    try {
      final file = await _getPlaylistUrlsFile();
      await file.writeAsString(jsonEncode(_playlistUrls));
    } catch (e) {
      debugPrint('Error saving playlist URLs: $e');
    }
  }

  /// Gets the stored online playlist URL for a given playlist folder name.
  Future<String?> getPlaylistUrl(String playlistName) async {
    if (!_isInitialized) await init();
    return _playlistUrls[playlistName.trim()];
  }

  /// Associates an online playlist URL with a playlist folder name and persists it.
  Future<void> setPlaylistUrl(String playlistName, String url) async {
    if (!_isInitialized) await init();
    final cleanName = playlistName.trim();
    final cleanUrl = url.trim();
    if (cleanName.isEmpty) return;

    if (cleanUrl.isEmpty) {
      _playlistUrls.remove(cleanName);
    } else {
      _playlistUrls[cleanName] = cleanUrl;
    }

    var changed = false;
    for (var i = 0; i < _cachedItems.length; i++) {
      if (_cachedItems[i].playlistName?.trim() == cleanName &&
          _cachedItems[i].playlistUrl != cleanUrl) {
        _cachedItems[i] = _cachedItems[i].copyWith(playlistUrl: cleanUrl);
        changed = true;
      }
    }
    if (changed) {
      await _persistToDisk();
    }
    await _persistPlaylistUrls();
  }

  /// Returns all cached downloads sorted by latest first.
  Future<List<DownloadItem>> getHistory() async {
    if (!_isInitialized) await init();
    return List.unmodifiable(
        _cachedItems..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  }

  /// Adds a completed download item to the persistent history.
  Future<void> addDownload(DownloadItem item) async {
    if (!_isInitialized) await init();
    _cachedItems.removeWhere((existing) => existing.id == item.id);
    _cachedItems.insert(0, item);

    if (item.playlistName != null &&
        item.playlistName!.trim().isNotEmpty &&
        item.playlistUrl != null &&
        item.playlistUrl!.trim().isNotEmpty) {
      _playlistUrls[item.playlistName!.trim()] = item.playlistUrl!.trim();
      await _persistPlaylistUrls();
    }

    await _persistToDisk();
  }

  /// Deletes a download from history and optionally removes the physical file from disk.
  Future<void> removeDownload(String id,
      {bool deletePhysicalFile = false}) async {
    if (!_isInitialized) await init();
    final index = _cachedItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _cachedItems[index];
      if (deletePhysicalFile && item.filePath.isNotEmpty) {
        try {
          final file = File(item.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting file ${item.filePath}: $e');
        }
      }
      _cachedItems.removeAt(index);
      await _persistToDisk();
    }
  }

  /// Clears all items from the history cache.
  Future<void> clearHistory() async {
    if (!_isInitialized) await init();
    _cachedItems.clear();
    await _persistToDisk();
  }

  /// Determines whether a video/track with the given title and format is already downloaded.
  /// Checks both the persistent history cache and the destination filesystem.
  Future<bool> isAlreadyDownloaded({
    required String title,
    required DownloadFormat format,
    String? targetDirectory,
  }) async {
    if (!_isInitialized) await init();

    // Audio files are now saved as .m4a (native stream, no re-encode).
    // Also check .mp3 as legacy fallback for items downloaded before this change.
    final audioExts = ['m4a', 'mp3', 'opus', 'ogg', 'aac'];
    final ext = format == DownloadFormat.mp3 ? 'm4a' : 'mp4';
    final cleanTitle = _sanitizeFilename(title).toLowerCase();

    // 1. Check in cached history items
    for (final item in _cachedItems) {
      if (item.format == format) {
        final itemCleanTitle = _sanitizeFilename(item.title).toLowerCase();
        if (itemCleanTitle == cleanTitle) {
          if (item.filePath.isNotEmpty) {
            try {
              if (await File(item.filePath).exists()) {
                return true;
              }
            } catch (_) {}
          }
        }
      }
    }

    // 2. Check destination directory on disk if provided
    if (targetDirectory != null && targetDirectory.isNotEmpty) {
      try {
        final dir = Directory(targetDirectory);
        if (await dir.exists()) {
          // Check primary extension first
          final expectedFile = File(p.join(targetDirectory, '$cleanTitle.$ext'));
          if (await expectedFile.exists()) return true;

          // For audio, also check legacy .mp3 and other audio containers
          if (format == DownloadFormat.mp3) {
            for (final altExt in audioExts) {
              final altFile = File(p.join(targetDirectory, '$cleanTitle.$altExt'));
              if (await altFile.exists()) return true;
            }
          }

          // Scan directory files for matching title (handles title-sanitization mismatches)
          final entities = await dir.list().toList();
          final validExts = format == DownloadFormat.mp3 ? audioExts : ['mp4', 'mkv', 'webm'];
          for (final entity in entities) {
            if (entity is File) {
              final fileName = p.basenameWithoutExtension(entity.path).toLowerCase();
              final fileExt = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
              if (validExts.contains(fileExt) &&
                  (fileName == cleanTitle || fileName.contains(cleanTitle))) {
                return true;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking destination directory for duplicate: $e');
      }
    }

    return false;
  }

  /// Silently updates the cached filePath for a download item without triggering full reloads.
  Future<void> updateItemFilePath(String id, String newFilePath) async {
    if (!_isInitialized) await init();
    final index = _cachedItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      _cachedItems[index] = _cachedItems[index].copyWith(filePath: newFilePath);
      await _persistToDisk();
    }
  }

  /// Moves one or more download items to a destination playlist folder, or null for Unorganized.
  /// Also moves physical files on disk if present.
  Future<void> moveItemsToPlaylist({
    required List<String> itemIds,
    required String? targetPlaylistName,
  }) async {
    if (!_isInitialized) await init();
    final cleanTarget =
        (targetPlaylistName != null && targetPlaylistName.trim().isNotEmpty)
            ? targetPlaylistName.trim()
            : null;

    final idSet = itemIds.toSet();
    for (var i = 0; i < _cachedItems.length; i++) {
      final item = _cachedItems[i];
      if (idSet.contains(item.id)) {
        var updatedFilePath = item.filePath;

        // Try moving physical file if it exists
        if (item.filePath.isNotEmpty) {
          try {
            final oldFile = File(item.filePath);
            if (await oldFile.exists()) {
              final targetDirStr = await SettingsService.instance
                  .resolveDownloadDirectoryForFormat(
                format: item.format,
                playlistName: cleanTarget,
              );
              final targetDir = Directory(targetDirStr);
              if (!await targetDir.exists()) {
                await targetDir.create(recursive: true);
              }

              final fileName = p.basename(item.filePath);
              var destPath = p.join(targetDir.path, fileName);

              if (p.canonicalize(destPath) != p.canonicalize(item.filePath)) {
                var counter = 1;
                final baseName = p.basenameWithoutExtension(fileName);
                final ext = p.extension(fileName);
                while (await File(destPath).exists()) {
                  destPath = p.join(targetDir.path, '$baseName ($counter)$ext');
                  counter++;
                }

                try {
                  await oldFile.rename(destPath);
                  updatedFilePath = destPath;
                } catch (_) {
                  await oldFile.copy(destPath);
                  await oldFile.delete();
                  updatedFilePath = destPath;
                }
              }
            }
          } catch (e) {
            debugPrint('Error moving physical file on disk: $e');
          }
        }

        _cachedItems[i] = item.copyWith(
          playlistName: cleanTarget,
          clearPlaylist: cleanTarget == null,
          filePath: updatedFilePath,
        );
      }
    }
    await _persistToDisk();
  }

  /// Renames an existing playlist across all history items and moves its physical directory on disk if present.
  Future<void> renamePlaylist({
    required String oldName,
    required String newName,
  }) async {
    if (!_isInitialized) await init();
    final cleanOld = oldName.trim();
    final cleanNew = newName.trim();
    if (cleanOld.isEmpty || cleanNew.isEmpty || cleanOld == cleanNew) return;

    // Try renaming directories on disk
    try {
      final baseDir = await SettingsService.instance.resolveDownloadDirectory();
      for (final parent in [baseDir, p.join(baseDir, 'Videos')]) {
        final oldFolder =
            Directory(p.join(parent, _sanitizeFilename(cleanOld)));
        final newFolder =
            Directory(p.join(parent, _sanitizeFilename(cleanNew)));
        if (await oldFolder.exists() && !await newFolder.exists()) {
          await oldFolder.rename(newFolder.path);
        }
      }
    } catch (e) {
      debugPrint('Error renaming playlist folder on disk: $e');
    }

    for (var i = 0; i < _cachedItems.length; i++) {
      final item = _cachedItems[i];
      if (item.playlistName?.trim() == cleanOld) {
        var updatedFilePath = item.filePath;
        if (item.filePath.isNotEmpty) {
          final oldSanitized = _sanitizeFilename(cleanOld);
          final newSanitized = _sanitizeFilename(cleanNew);
          if (item.filePath.contains(oldSanitized)) {
            updatedFilePath =
                item.filePath.replaceAll(oldSanitized, newSanitized);
          }
        }
        _cachedItems[i] = item.copyWith(
          playlistName: cleanNew,
          filePath: updatedFilePath,
        );
      }
    }

    if (_playlistUrls.containsKey(cleanOld)) {
      final url = _playlistUrls.remove(cleanOld)!;
      _playlistUrls[cleanNew] = url;
      await _persistPlaylistUrls();
    }

    await _persistToDisk();
  }

  /// Deletes a playlist and all its items from history, optionally deleting files on disk.
  Future<void> deletePlaylist({
    required String playlistName,
    bool deletePhysicalFiles = false,
  }) async {
    if (!_isInitialized) await init();
    final cleanName = playlistName.trim();

    final toRemove = _cachedItems
        .where((item) => item.playlistName?.trim() == cleanName)
        .map((e) => e.id)
        .toList();

    for (final id in toRemove) {
      await removeDownload(id, deletePhysicalFile: deletePhysicalFiles);
    }

    _playlistUrls.remove(cleanName);
    await _persistPlaylistUrls();
  }

  static String _sanitizeFilename(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  }
}
