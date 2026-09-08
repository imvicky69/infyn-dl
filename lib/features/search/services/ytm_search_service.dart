import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../downloader/services/android_downloader_service.dart';
import '../../library/models/track.dart';

/// Fast search service using youtube_explode_dart and YouTube Music Innertube API.
class YtmSearchService {
  YtmSearchService._();
  static final YtmSearchService instance = YtmSearchService._();

  final yt.YoutubeExplode _yt = yt.YoutubeExplode();

  /// Searches YouTube and maps results to Track models.
  Future<List<Track>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final searchResults = await _yt.search.search(query);

      return searchResults.map((video) {
        return Track(
          id: video.id.value,
          title: video.title,
          artist: video.author, // Video author is usually the artist/channel
          webUrl: video.url,
          duration: video.duration,
          artworkPath: video.thumbnails.highResUrl,
        );
      }).toList();
    } catch (e) {
      debugPrint('YtmSearchService search error: $e');
      return [];
    }
  }

  /// Searches for playlists
  Future<List<yt.SearchPlaylist>> searchPlaylists(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final results = await _yt.search
          .searchContent(query, filter: yt.TypeFilters.playlist);
      return results.whereType<yt.SearchPlaylist>().toList();
    } catch (e) {
      debugPrint('YtmSearchService playlist search error: $e');
      return [];
    }
  }

  /// Gets all tracks for a playlist using multiple reliable strategies:
  /// 1. YouTube Music Innertube API (`WEB_REMIX` client with pagination)
  /// 2. Native yt-dlp extractor via AndroidDownloaderService (on Android)
  /// 3. youtube_explode_dart fallback
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    // 1. Try YouTube Music Innertube API
    try {
      final ytmTracks = await _getTracksFromYtMusic(playlistId);
      if (ytmTracks.isNotEmpty) {
        debugPrint(
            'YtmSearchService: Fetched ${ytmTracks.length} tracks via YTM Innertube');
        return ytmTracks;
      }
    } catch (e) {
      debugPrint('YtmSearchService YtMusic API error: $e');
    }

    // 2. Try native yt-dlp on Android
    try {
      if (Platform.isAndroid) {
        final nativeTracks = await _getTracksFromNativeDownloader(playlistId);
        if (nativeTracks.isNotEmpty) {
          debugPrint(
              'YtmSearchService: Fetched ${nativeTracks.length} tracks via native downloader');
          return nativeTracks;
        }
      }
    } catch (e) {
      debugPrint('YtmSearchService native downloader error: $e');
    }

    // 3. Fallback to youtube_explode_dart
    try {
      final ytExplodeTracks = await _getTracksFromYoutubeExplode(playlistId);
      if (ytExplodeTracks.isNotEmpty) {
        debugPrint(
            'YtmSearchService: Fetched ${ytExplodeTracks.length} tracks via youtube_explode_dart');
        return ytExplodeTracks;
      }
    } catch (e) {
      debugPrint('YtmSearchService youtube_explode_dart error: $e');
    }

    return [];
  }

  /// Fetches playlist tracks via YouTube Music Innertube browse API
  Future<List<Track>> _getTracksFromYtMusic(String playlistId) async {
    final cleanId = playlistId.replaceAll('VL', '');
    final browseId = 'VL$cleanId';

    final response = await http.post(
      Uri.parse(
          'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://music.youtube.com/',
      },
      body: jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240101.01.00',
            'hl': 'en',
            'gl': 'US',
          },
        },
        'browseId': browseId,
      }),
    );

    if (response.statusCode != 200) return [];
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final results = <Track>[];
    final seenIds = <String>{};

    void extractFromRenderers(dynamic obj) {
      if (obj is Map) {
        if (obj.containsKey('musicResponsiveListItemRenderer')) {
          final r =
              obj['musicResponsiveListItemRenderer'] as Map<String, dynamic>;
          final videoId = r['playlistItemData']?['videoId'] as String?;
          if (videoId != null &&
              videoId.isNotEmpty &&
              !seenIds.contains(videoId)) {
            seenIds.add(videoId);

            var title = 'Unknown Title';
            var artist = 'Unknown Artist';
            Duration? duration;

            final flexColumns = r['flexColumns'] as List<dynamic>? ?? [];
            if (flexColumns.isNotEmpty) {
              final runs = flexColumns[0]?['musicResponsiveListItemFlexColumnRenderer']
                      ?['text']?['runs'] as List<dynamic>?;
              if (runs != null && runs.isNotEmpty) {
                title = runs.map((e) => e['text']).join();
              }
            }
            if (flexColumns.length > 1) {
              final runs = flexColumns[1]?['musicResponsiveListItemFlexColumnRenderer']
                      ?['text']?['runs'] as List<dynamic>?;
              if (runs != null && runs.isNotEmpty) {
                artist = runs.map((e) => e['text']).join();
              }
            }

            final fixedColumns = r['fixedColumns'] as List<dynamic>? ?? [];
            if (fixedColumns.isNotEmpty) {
              final runs = fixedColumns[0]
                          ?['musicResponsiveListItemFixedColumnRenderer']
                      ?['text']?['runs'] as List<dynamic>?;
              if (runs != null && runs.isNotEmpty) {
                final durStr = runs.first['text'] as String?;
                duration = _parseDuration(durStr);
              }
            }

            results.add(
              Track(
                id: videoId,
                title: title,
                artist: artist,
                webUrl: 'https://www.youtube.com/watch?v=$videoId',
                duration: duration,
                artworkPath: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
              ),
            );
          }
        } else {
          for (final val in obj.values) {
            extractFromRenderers(val);
          }
        }
      } else if (obj is List) {
        for (final item in obj) {
          extractFromRenderers(item);
        }
      }
    }

    extractFromRenderers(json);

    // Handle continuations if playlist has more than 100 tracks
    String? continuationToken;
    void findContinuation(dynamic obj) {
      if (continuationToken != null) return;
      if (obj is Map) {
        if (obj.containsKey('continuationCommand')) {
          continuationToken = obj['continuationCommand']?['token'] as String?;
        } else {
          for (final v in obj.values) {
            findContinuation(v);
          }
        }
      } else if (obj is List) {
        for (final item in obj) {
          findContinuation(item);
        }
      }
    }

    findContinuation(json);
    var paginationLimit = 10; // Up to 1000 tracks
    while (continuationToken != null && paginationLimit-- > 0) {
      final token = continuationToken;
      continuationToken = null;
      try {
        final contResp = await http.post(
          Uri.parse(
              'https://music.youtube.com/youtubei/v1/browse?continuation=$token&prettyPrint=false'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://music.youtube.com/',
          },
          body: jsonEncode({
            'context': {
              'client': {
                'clientName': 'WEB_REMIX',
                'clientVersion': '1.20240101.01.00',
                'hl': 'en',
                'gl': 'US',
              },
            },
          }),
        );

        if (contResp.statusCode == 200) {
          final contJson = jsonDecode(contResp.body) as Map<String, dynamic>;
          extractFromRenderers(contJson);
          findContinuation(contJson);
        }
      } catch (e) {
        debugPrint('YtmSearchService continuation error: $e');
        break;
      }
    }

    return results;
  }

  /// Fetches playlist tracks via native AndroidDownloaderService using yt-dlp
  Future<List<Track>> _getTracksFromNativeDownloader(String playlistId) async {
    final cleanId = playlistId.replaceAll('VL', '');
    final url = 'https://www.youtube.com/playlist?list=$cleanId';
    final metadata =
        await AndroidDownloaderService().fetchPlaylistMetadata(url);
    if (metadata == null || metadata.entries.isEmpty) return [];

    return metadata.entries.map((entry) {
      return Track(
        id: entry.id,
        title: entry.title,
        artist: entry.uploader ?? 'Unknown Artist',
        webUrl: entry.url,
        duration:
            entry.duration > 0 ? Duration(seconds: entry.duration) : null,
        artworkPath: entry.bestThumbnailUrl,
      );
    }).toList();
  }

  /// Fallback: fetches tracks via youtube_explode_dart
  Future<List<Track>> _getTracksFromYoutubeExplode(String playlistId) async {
    final playlist = await _yt.playlists.get(playlistId);
    final videos = await _yt.playlists.getVideos(playlist.id).toList();
    return videos.map((video) {
      return Track(
        id: video.id.value,
        title: video.title,
        artist: video.author,
        webUrl: video.url,
        duration: video.duration,
        artworkPath: video.thumbnails.highResUrl,
      );
    }).toList();
  }

  Duration? _parseDuration(String? text) {
    if (text == null || text.isEmpty) return null;
    final parts = text.trim().split(':');
    try {
      if (parts.length == 2) {
        final m = int.parse(parts[0]);
        final s = int.parse(parts[1]);
        return Duration(minutes: m, seconds: s);
      } else if (parts.length == 3) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final s = int.parse(parts[2]);
        return Duration(hours: h, minutes: m, seconds: s);
      }
    } catch (_) {}
    return null;
  }

  void dispose() {
    _yt.close();
  }
}
