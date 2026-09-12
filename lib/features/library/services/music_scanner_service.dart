import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../downloader/services/android_downloader_service.dart';
import '../../downloader/services/download_history_service.dart';
import '../../home/services/catalog_service.dart';
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
    '.opus',
    '.ogg',
    '.aac',
    '.webm',
  };

  final ValueNotifier<List<Track>> tracksNotifier =
      ValueNotifier<List<Track>>([]);
  final ValueNotifier<List<MusicPlaylist>> playlistsNotifier =
      ValueNotifier<List<MusicPlaylist>>([]);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier<bool>(false);

  final Map<String, Duration> _durationCache = {};
  bool _durationCacheLoaded = false;

  List<Track> get tracks => tracksNotifier.value;
  List<MusicPlaylist> get playlists => playlistsNotifier.value;
  bool get isScanning => isScanningNotifier.value;

  Future<void> _ensureDurationCacheLoaded() async {
    if (_durationCacheLoaded) return;
    _durationCacheLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('cached_audio_durations');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          if (val is num && val > 0) {
            _durationCache[key] = Duration(milliseconds: val.toInt());
          }
        });
      }
    } catch (_) {}
  }

  void _saveDurationCache() {
    SharedPreferences.getInstance().then((prefs) {
      final map = <String, int>{};
      _durationCache.forEach((key, val) {
        map[key] = val.inMilliseconds;
      });
      prefs.setString('cached_audio_durations', json.encode(map));
    }).catchError((_) {});
  }

  /// Updates duration for a specific track and saves it in the duration cache.
  void updateTrackDuration(String trackId, Duration duration) {
    if (duration <= Duration.zero) return;
    final currentTracks = tracksNotifier.value;
    final index = currentTracks.indexWhere(
        (t) => t.id == trackId || (t.filePath != null && t.filePath == trackId));
    if (index != -1) {
      final old = currentTracks[index];
      if (old.duration != duration) {
        if (old.filePath != null) {
          _durationCache[old.filePath!] = duration;
          _saveDurationCache();
        }
        final updated = List<Track>.from(currentTracks);
        updated[index] = old.copyWith(duration: duration);
        tracksNotifier.value = updated;
      }
    }
  }

  /// Scans the download directory recursively for music files.
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
          final raw = p.basenameWithoutExtension(item.filePath).toLowerCase();
          historyLookup[normalized] = item;
          historyLookup[basename] = item;
          historyLookup[raw] = item;
        }
        if (item.title.isNotEmpty) {
          historyLookup[item.title.toLowerCase()] = item;
        }
      }

      final List<Track> discovered = [];
      final Set<String> seenNormalizedPaths = {};

      try {
        final entities =
            await baseDir.list(recursive: true, followLinks: false).toList();

        for (final entity in entities) {
          if (entity is! File) continue;

          final ext = p.extension(entity.path).toLowerCase();
          if (!supportedExtensions.contains(ext)) continue;

          final filePath = entity.path;
          final normalizedPath = p.normalize(filePath).toLowerCase();
          if (seenNormalizedPaths.contains(normalizedPath)) continue;
          seenNormalizedPaths.add(normalizedPath);

          final fileBasename = p.basename(filePath).toLowerCase();
          final rawName = p.basenameWithoutExtension(filePath);

          // Check for matching history item
          final matchedHistory = historyLookup[normalizedPath] ??
              historyLookup[fileBasename] ??
              historyLookup[rawName.toLowerCase()];

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
              webUrl: matchedHistory?.url,
              duration: duration,
              album: album,
              artworkPath: artworkPath,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error listing files in directory: $e');
      }

      // Load cached audio durations
      await _ensureDurationCacheLoaded();

      // Populate missing durations from cache and native Android MediaMetadataRetriever
      final missingDurationPaths = <String>[];
      for (var i = 0; i < discovered.length; i++) {
        final t = discovered[i];
        if (t.duration == null && t.filePath != null) {
          final cached = _durationCache[t.filePath!];
          if (cached != null) {
            discovered[i] = t.copyWith(duration: cached);
          } else {
            missingDurationPaths.add(t.filePath!);
          }
        }
      }

      if (missingDurationPaths.isNotEmpty) {
        try {
          final nativeDurations = await AndroidDownloaderService.instance
              .getAudioDurations(missingDurationPaths);
          if (nativeDurations.isNotEmpty) {
            for (final entry in nativeDurations.entries) {
              if (entry.value > 0) {
                _durationCache[entry.key] = Duration(milliseconds: entry.value);
              }
            }
            _saveDurationCache();
            for (var i = 0; i < discovered.length; i++) {
              final t = discovered[i];
              if (t.duration == null &&
                  t.filePath != null &&
                  _durationCache.containsKey(t.filePath!)) {
                discovered[i] =
                    t.copyWith(duration: _durationCache[t.filePath!]);
              }
            }
          }
        } catch (e) {
          debugPrint('Error retrieving native audio durations: $e');
        }
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

        // Fallback 1: Extract YouTube thumbnail from track webUrl if available
        if (playlistCover == null || playlistCover.isEmpty) {
          for (final track in entry.value) {
            if (track.webUrl != null && track.webUrl!.isNotEmpty) {
              final regExp = RegExp(
                  r'(?:v=|youtu\.be\/|embed\/|shorts\/)([a-zA-Z0-9_-]{11})');
              final match = regExp.firstMatch(track.webUrl!);
              if (match != null) {
                playlistCover =
                    'https://img.youtube.com/vi/${match.group(1)}/hqdefault.jpg';
                break;
              }
            }
          }
        }

        // Fallback 2: Check if playlist matches any catalog playlist by name
        if (playlistCover == null || playlistCover.isEmpty) {
          for (final c in CatalogService.instance.playlists) {
            if (c.title.toLowerCase() == entry.key.toLowerCase()) {
              playlistCover = c.thumbnailUrl;
              break;
            }
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
