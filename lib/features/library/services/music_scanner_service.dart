import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../downloader/services/download_history_service.dart';
import '../../settings/services/settings_service.dart';
import '../models/music_playlist.dart';
import '../models/track.dart';

/// Scans the local/downloaded music directory for supported audio files
/// and organizes them into playlists and tracks.
class MusicScannerService {
  static MusicScannerService? _instance;
  static MusicScannerService get instance =>
      _instance ??= MusicScannerService._();

  MusicScannerService._();

  static const Set<String> supportedExtensions = {
    '.mp3',
    '.m4a',
    '.wav',
    '.flac',
  };

  final ValueNotifier<List<Track>> tracksNotifier =
      ValueNotifier<List<Track>>([]);
  final ValueNotifier<List<MusicPlaylist>> playlistsNotifier =
      ValueNotifier<List<MusicPlaylist>>([]);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier<bool>(false);

  List<Track> get tracks => tracksNotifier.value;
  List<MusicPlaylist> get playlists => playlistsNotifier.value;

  /// Scans the download directory recursively for audio files.
  Future<List<Track>> scanMusicDirectory({bool forceRefresh = false}) async {
    if (isScanningNotifier.value) {
      return tracksNotifier.value;
    }

    isScanningNotifier.value = true;

    try {
      final baseDirPath =
          await SettingsService.instance.resolveDownloadDirectory();
      final baseDir = Directory(baseDirPath);

      if (!await baseDir.exists()) {
        tracksNotifier.value = [];
        playlistsNotifier.value = [];
        return [];
      }

      // Load download history for enriched metadata matching
      final history = await DownloadHistoryService.instance.getHistory();
      final Map<String, dynamic> historyLookup = {};
      for (final item in history) {
        if (item.filePath.isNotEmpty) {
          final normalized = p.normalize(item.filePath).toLowerCase();
          final basename = p.basename(item.filePath).toLowerCase();
          historyLookup[normalized] = item;
          historyLookup[basename] = item;
        }
      }

      final List<Track> discovered = [];

      try {
        final entities =
            await baseDir.list(recursive: true, followLinks: false).toList();

        for (final entity in entities) {
          if (entity is! File) continue;

          final ext = p.extension(entity.path).toLowerCase();
          if (!supportedExtensions.contains(ext)) continue;

          final filePath = entity.path;
          final normalizedPath = p.normalize(filePath).toLowerCase();
          final fileBasename = p.basename(filePath).toLowerCase();
          final rawName = p.basenameWithoutExtension(filePath);

          // Check for matching history item
          final matchedHistory =
              historyLookup[normalizedPath] ?? historyLookup[fileBasename];

          String title;
          String artist;
          Duration? duration;
          String? artworkPath;
          String? album;

          if (matchedHistory != null) {
            title = matchedHistory.title.isNotEmpty
                ? matchedHistory.title
                : _cleanTrackTitle(rawName);
            artist = _extractArtistFromFilename(rawName);
            if (matchedHistory.thumbnailUrl != null &&
                matchedHistory.thumbnailUrl!.trim().isNotEmpty) {
              artworkPath = matchedHistory.thumbnailUrl;
            }
            if (matchedHistory.playlistName != null &&
                matchedHistory.playlistName!.trim().isNotEmpty) {
              album = matchedHistory.playlistName;
            }
          } else {
            // Parse from filename
            artist = _extractArtistFromFilename(rawName);
            title = _extractTitleFromFilename(rawName);
          }

          // Infer playlist/folder name from parent directory if not set
          final parentDir = p.dirname(filePath);
          if (album == null || album.trim().isEmpty) {
            if (p.normalize(parentDir).toLowerCase() !=
                p.normalize(baseDirPath).toLowerCase()) {
              album = p.basename(parentDir);
            }
          }

          // Check if local artwork exists next to audio file or in parent directory
          if (artworkPath == null) {
            final possibleArtworks = [
              p.join(parentDir, '$rawName.jpg'),
              p.join(parentDir, '$rawName.jpeg'),
              p.join(parentDir, '$rawName.png'),
              p.join(parentDir, '$rawName.webp'),
              p.join(parentDir, 'folder.jpg'),
              p.join(parentDir, 'cover.jpg'),
              p.join(parentDir, 'cover.png'),
            ];
            for (final artPath in possibleArtworks) {
              if (await File(artPath).exists()) {
                artworkPath = artPath;
                break;
              }
            }
          }

          discovered.add(
            Track(
              id: filePath,
              title: title,
              artist: artist,
              filePath: filePath,
              duration: duration,
              album: album,
              artworkPath: artworkPath,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error listing files in directory: $e');
      }

      // Sort tracks alphabetically by title
      discovered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

      tracksNotifier.value = discovered;

      // Group tracks into playlists (by album / folder)
      final Map<String, List<Track>> grouped = {};
      for (final track in discovered) {
        final playlistName = track.album?.trim().isNotEmpty == true
            ? track.album!.trim()
            : 'Downloads';
        grouped.putIfAbsent(playlistName, () => []).add(track);
      }

      final List<MusicPlaylist> playlistsList = [];
      for (final entry in grouped.entries) {
        // Find first track with artwork to serve as playlist cover
        String? playlistCover;
        for (final track in entry.value) {
          if (track.artworkPath != null && track.artworkPath!.isNotEmpty) {
            playlistCover = track.artworkPath;
            break;
          }
        }

        playlistsList.add(
          MusicPlaylist(
            name: entry.key,
            tracks: entry.value,
            artworkPath: playlistCover,
          ),
        );
      }

      // Sort playlists: named playlists alphabetically, "Downloads" last
      playlistsList.sort((a, b) {
        if (a.name == 'Downloads') return 1;
        if (b.name == 'Downloads') return -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      playlistsNotifier.value = playlistsList;

      return discovered;
    } catch (e) {
      debugPrint('Error scanning music directory: $e');
      return tracksNotifier.value;
    } finally {
      isScanningNotifier.value = false;
    }
  }

  static String _extractArtistFromFilename(String filename) {
    if (filename.contains(' - ')) {
      final parts = filename.split(' - ');
      return parts[0].trim();
    }
    return 'Unknown Artist';
  }

  static String _extractTitleFromFilename(String filename) {
    if (filename.contains(' - ')) {
      final parts = filename.split(' - ');
      return _cleanTrackTitle(parts.sublist(1).join(' - '));
    }
    return _cleanTrackTitle(filename);
  }

  static String _cleanTrackTitle(String title) {
    var cleaned = title
        .replaceAll(
          RegExp(
            r'\s*[\(\[](?:Official\s+(?:Video|Audio|Music\s+Video)|Lyric\s+Video|HD|4K|Audio)[\)\]]',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return cleaned.isNotEmpty ? cleaned : title;
  }
}
