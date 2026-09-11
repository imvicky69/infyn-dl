import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../downloader/models/ytm_search_result.dart';
import '../../downloader/services/android_downloader_service.dart';
import '../../library/models/track.dart';
import '../models/search_playlist_info.dart';

/// Consolidated YouTube Music Search Service.
/// Uses the YouTube Music internal Innertube API (WEB_REMIX client) as canonical
/// for pure music search with rich metadata (artist, album, duration, artwork),
/// with automatic fallbacks to youtube_explode_dart.
class YtmSearchService {
  YtmSearchService._();
  static final YtmSearchService instance = YtmSearchService._();

  final yt.YoutubeExplode _yt = yt.YoutubeExplode();

  // ── YouTube Music Innertube API Constants ──────────────────────────────────
  static const String _baseUrl = 'https://music.youtube.com/youtubei/v1/';
  static const String _apiKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  // Base64 encoded filter tokens for YTM categories
  static const String _paramsSongs = 'EgWKAQIIAWoKEAoQAxAEEAkQBQ%3D%3D';
  static const String _paramsPlaylists = 'EgWKAQIoAWoKEAoQAxAEEAkQBQ%3D%3D';
  static const String _paramsAlbums = 'EgWKAQIYAWoKEAoQAxAEEAkQBQ%3D%3D';
  static const String _paramsVideos = 'EgWKAQIQAWoKEAoQAxAEEAkQBQ%3D%3D';

  static Map<String, dynamic> _buildContext() => {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20240101.01.00',
          'hl': 'en',
          'gl': 'US',
          'userAgent': _userAgent,
        }
      };

  Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body, {
    String? params,
  }) async {
    try {
      final queryParams =
          'alt=json&key=$_apiKey${params != null ? '&$params' : ''}';
      final uri = Uri.parse('$_baseUrl$endpoint?$queryParams');

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('User-Agent', _userAgent);
      request.headers.set('Origin', 'https://music.youtube.com');
      request.headers.set('Referer', 'https://music.youtube.com/');
      request.headers.set('X-YouTube-Client-Name', '67');
      request.headers.set('X-YouTube-Client-Version', '1.20240101.01.00');

      final bodyBytes = utf8.encode(jsonEncode(body));
      request.contentLength = bodyBytes.length;
      request.add(bodyBytes);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) {
        debugPrint('YTM Innertube: HTTP ${response.statusCode}');
        return null;
      }

      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('YTM Innertube _post error: $e');
      return null;
    }
  }

  // ── Public Search APIs ─────────────────────────────────────────────────────

  /// Searches YouTube Music for songs, returning rich Track models.
  /// Falls back to youtube_explode_dart if Innertube is unavailable.
  Future<List<Track>> searchTracks(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // 1. Try YouTube Music Innertube API first (canonical music experience)
    try {
      final ytmResults =
          await _searchYtm(cleanQuery, params: _paramsSongs, type: 'song');
      if (ytmResults.isNotEmpty) {
        final tracks = <Track>[];
        for (final r in ytmResults) {
          final id = r.videoId ??
              (r.url.contains('v=')
                  ? r.url.split('v=').last.split('&').first
                  : r.url);
          if (id.isEmpty) continue;
          tracks.add(Track(
            id: id,
            title: r.title,
            artist: r.artist ?? 'Unknown Artist',
            album: r.album,
            duration: _parseDuration(r.duration),
            artworkPath: r.thumbnailUrl,
            webUrl: r.url.isNotEmpty
                ? r.url
                : 'https://www.youtube.com/watch?v=$id',
          ));
        }
        if (tracks.isNotEmpty) {
          debugPrint(
              'YtmSearchService: Found ${tracks.length} songs via YTM Innertube');
          return tracks;
        }
      }
    } catch (e) {
      debugPrint('YtmSearchService Innertube songs error: $e');
    }

    // 2. Fallback to youtube_explode_dart
    try {
      debugPrint(
          'YtmSearchService: Falling back to youtube_explode_dart for "$cleanQuery"');
      final searchResults = await _yt.search.search(cleanQuery);
      return searchResults.map((video) {
        return Track(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          webUrl: video.url,
          duration: video.duration,
          artworkPath: video.thumbnails.highResUrl,
        );
      }).toList();
    } catch (e) {
      debugPrint('YtmSearchService youtube_explode fallback error: $e');
      return [];
    }
  }

  /// Searches YouTube Music for playlists & albums.
  /// Returns unified [SearchPlaylistInfo] models.
  Future<List<SearchPlaylistInfo>> searchPlaylists(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // 1. Try YouTube Music Innertube API
    try {
      final ytmResults = await _searchYtm(cleanQuery,
          params: _paramsPlaylists, type: 'playlist');
      if (ytmResults.isNotEmpty) {
        final list = <SearchPlaylistInfo>[];
        for (final r in ytmResults) {
          String? pId = r.browseId;
          if (pId != null && pId.startsWith('VL')) {
            pId = pId.substring(2);
          }
          if (pId == null || pId.isEmpty) {
            if (r.url.contains('list=')) {
              pId = r.url.split('list=').last.split('&').first;
            }
          }
          if (pId == null || pId.isEmpty) continue;

          list.add(SearchPlaylistInfo(
            id: pId,
            title: r.title,
            author: r.artist,
            thumbnailUrl: r.thumbnailUrl,
            trackCount: r.trackCount,
          ));
        }
        if (list.isNotEmpty) {
          debugPrint(
              'YtmSearchService: Found ${list.length} playlists via YTM Innertube');
          return list;
        }
      }
    } catch (e) {
      debugPrint('YtmSearchService Innertube playlists error: $e');
    }

    // 2. Fallback to youtube_explode_dart
    try {
      debugPrint(
          'YtmSearchService: Falling back to youtube_explode_dart for playlists');
      final results = await _yt.search
          .searchContent(cleanQuery, filter: yt.TypeFilters.playlist);
      final playlists = results.whereType<yt.SearchPlaylist>().toList();
      return playlists.map((p) {
        final thumb =
            p.thumbnails.isNotEmpty ? p.thumbnails.first.url.toString() : null;
        return SearchPlaylistInfo(
          id: p.id.value,
          title: p.title,
          author: null,
          thumbnailUrl: thumb,
          trackCount: p.videoCount,
        );
      }).toList();
    } catch (e) {
      debugPrint(
          'YtmSearchService youtube_explode playlist fallback error: $e');
      return [];
    }
  }

  /// Raw search returning YtmSearchResult for sheet or advanced multi-category filters.
  Future<List<YtmSearchResult>> searchYtmResults(
    String query, {
    String category = 'songs',
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    switch (category) {
      case 'playlists':
        return _searchYtm(clean, params: _paramsPlaylists, type: 'playlist');
      case 'albums':
        return _searchYtm(clean, params: _paramsAlbums, type: 'album');
      case 'videos':
        return _searchYtm(clean, params: _paramsVideos, type: 'video');
      case 'songs':
      default:
        return _searchYtm(clean, params: _paramsSongs, type: 'song');
    }
  }

  // ── Innertube Search Internals ─────────────────────────────────────────────

  Future<List<YtmSearchResult>> _searchYtm(
    String query, {
    String? params,
    String? type,
  }) async {
    final body = <String, dynamic>{
      'context': _buildContext(),
      'query': query,
      if (params != null) 'params': Uri.decodeQueryComponent(params),
    };

    final json = await _post('search', body, params: params);
    if (json == null) return [];

    try {
      return _parseResults(json, expectedType: type);
    } catch (e) {
      debugPrint('YtmSearchService._parseResults error: $e');
      return [];
    }
  }

  List<YtmSearchResult> _parseResults(
    Map<String, dynamic> json, {
    String? expectedType,
  }) {
    final results = <YtmSearchResult>[];

    final tabs = _nav(json, ['contents', 'tabbedSearchResultsRenderer', 'tabs'])
        as List?;
    final tabContents = tabs != null && tabs.isNotEmpty
        ? _nav(tabs[0], ['tabRenderer', 'content'])
        : null;

    final sectionList = _nav(
          tabContents ?? json['contents'],
          ['sectionListRenderer', 'contents'],
        ) as List? ??
        [];

    for (final section in sectionList) {
      final sectionMap = section as Map<String, dynamic>;
      final shelf = sectionMap['musicShelfRenderer'] as Map<String, dynamic>?;
      if (shelf == null) continue;

      final items = shelf['contents'] as List? ?? [];
      for (final item in items) {
        final parsed = _parseItem(
          item as Map<String, dynamic>,
          expectedType: expectedType,
        );
        if (parsed != null) results.add(parsed);
      }
    }

    return results;
  }

  YtmSearchResult? _parseItem(
    Map<String, dynamic> item, {
    String? expectedType,
  }) {
    final renderer =
        item['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
    if (renderer == null) return null;

    final title = _extractText(
      _nav(renderer, [
        'flexColumns',
        0,
        'musicResponsiveListItemFlexColumnRenderer',
        'text',
      ]),
    );
    if (title == null || title.isEmpty) return null;

    final thumbnails = _nav(renderer, [
      'thumbnail',
      'musicThumbnailRenderer',
      'thumbnail',
      'thumbnails'
    ]) as List?;
    final thumbUrl = thumbnails != null && thumbnails.isNotEmpty
        ? _bestThumb(thumbnails)
        : null;

    final col2 = _nav(renderer, [
      'flexColumns',
      1,
      'musicResponsiveListItemFlexColumnRenderer',
      'text',
      'runs',
    ]) as List?;

    String? artist;
    String? album;
    String? duration;
    String? detectedType = expectedType;
    int? trackCount;

    if (col2 != null) {
      final texts = col2
          .whereType<Map<String, dynamic>>()
          .map((r) => r['text'] as String? ?? '')
          .where((t) => t.trim().isNotEmpty && t.trim() != '•')
          .toList();

      if (texts.isNotEmpty) {
        final typeCandidate = texts[0].toLowerCase();
        if (typeCandidate == 'song' || typeCandidate == 'single') {
          detectedType = 'song';
          if (texts.length > 1) artist = texts[1];
          if (texts.length > 2) album = texts[2];
          if (texts.length > 3) duration = texts.last;
        } else if (typeCandidate.contains('playlist')) {
          detectedType = 'playlist';
          if (texts.length > 1) artist = texts[1];
          final trackText = texts.firstWhere(
            (t) => t.contains('song') || t.contains('track'),
            orElse: () => '',
          );
          if (trackText.isNotEmpty) {
            trackCount = int.tryParse(trackText.split(' ').first);
          }
        } else if (typeCandidate == 'album' || typeCandidate == 'ep') {
          detectedType = 'album';
          if (texts.length > 1) artist = texts[1];
        } else if (typeCandidate == 'video') {
          detectedType = 'video';
          if (texts.length > 1) artist = texts[1];
          if (texts.length > 2) duration = texts.last;
        } else {
          artist = texts[0];
          if (texts.length > 1) {
            final last = texts.last;
            if (RegExp(r'^\d+:\d+$').hasMatch(last)) duration = last;
          }
        }
      }
    }

    detectedType ??= 'song';

    final navEndpoint = _nav(renderer, [
      'overlay',
      'musicItemThumbnailOverlayRenderer',
      'content',
      'musicPlayButtonRenderer',
      'playNavigationEndpoint',
    ]) as Map<String, dynamic>?;

    final watchEndpoint =
        navEndpoint?['watchEndpoint'] as Map<String, dynamic>?;
    final videoId = watchEndpoint?['videoId'] as String?;
    final playlistId = watchEndpoint?['playlistId'] as String?;

    final browseEndpoint =
        _nav(renderer, ['navigationEndpoint', 'browseEndpoint'])
            as Map<String, dynamic>?;
    final browseId = browseEndpoint?['browseId'] as String?;

    final titleRuns = _nav(renderer, [
          'flexColumns',
          0,
          'musicResponsiveListItemFlexColumnRenderer',
          'text',
          'runs',
        ]) as List? ??
        [];

    String? titleVideoId = videoId;
    String? titlePlaylistId = playlistId;
    String? titleBrowseId = browseId;

    for (final run in titleRuns.whereType<Map<String, dynamic>>()) {
      final navEp = run['navigationEndpoint'] as Map<String, dynamic>?;
      if (navEp == null) continue;
      final we = navEp['watchEndpoint'] as Map<String, dynamic>?;
      final be = navEp['browseEndpoint'] as Map<String, dynamic>?;
      if (we != null) {
        titleVideoId ??= we['videoId'] as String?;
        titlePlaylistId ??= we['playlistId'] as String?;
      }
      if (be != null) {
        titleBrowseId ??= be['browseId'] as String?;
      }
    }

    String url = '';
    String? finalBrowseId = titleBrowseId;

    if (detectedType == 'playlist' || detectedType == 'album') {
      if (finalBrowseId != null) {
        final listId = finalBrowseId.startsWith('VL')
            ? finalBrowseId.substring(2)
            : finalBrowseId;
        url = 'https://music.youtube.com/playlist?list=$listId';
      } else if (titlePlaylistId != null) {
        url = 'https://music.youtube.com/playlist?list=$titlePlaylistId';
      }
    } else {
      final effectiveVideoId = titleVideoId ?? videoId;
      if (effectiveVideoId != null) {
        url = 'https://music.youtube.com/watch?v=$effectiveVideoId';
      }
    }

    return YtmSearchResult(
      type: detectedType,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      thumbnailUrl: thumbUrl,
      url: url,
      browseId: finalBrowseId,
      videoId: titleVideoId ?? videoId,
      trackCount: trackCount,
    );
  }

  // ── Playlist Tracks Cache ──────────────────────────────────────────────────
  static final Map<String, List<Track>> _playlistTracksMemoryCache = {};
  static final Map<String, DateTime> _playlistTracksCacheTime = {};

  /// Synchronously returns cached playlist tracks if in memory.
  List<Track>? getCachedPlaylistTracksSync(String playlistId) {
    return _playlistTracksMemoryCache[playlistId];
  }

  /// Returns cached playlist tracks from memory or SharedPreferences, or null.
  Future<List<Track>?> getCachedPlaylistTracks(String playlistId) async {
    final inMem = _playlistTracksMemoryCache[playlistId];
    if (inMem != null && inMem.isNotEmpty) return inMem;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cached_playlist_tracks_$playlistId';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final tracks = decoded
            .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        if (tracks.isNotEmpty) {
          _playlistTracksMemoryCache[playlistId] = tracks;
          return tracks;
        }
      }
    } catch (e) {
      debugPrint('YtmSearchService getCachedPlaylistTracks error: $e');
    }
    return null;
  }

  Future<void> _cachePlaylistTracks(
      String playlistId, List<Track> tracks) async {
    if (tracks.isEmpty) return;
    _playlistTracksMemoryCache[playlistId] = tracks;
    _playlistTracksCacheTime[playlistId] = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cached_playlist_tracks_$playlistId';
      final jsonList = tracks.map((t) => t.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      await prefs.setInt('${key}_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('YtmSearchService _cachePlaylistTracks error: $e');
    }
  }

  // ── Playlist Tracks Fetcher (3-tier Strategy + Cache) ──────────────────────

  /// Gets all tracks for a playlist using cached data or multiple reliable strategies:
  /// 1. Memory / Persistent local cache
  /// 2. YouTube Music Innertube API (`WEB_REMIX` client with pagination)
  /// 3. Native yt-dlp extractor via AndroidDownloaderService (on Android)
  /// 4. youtube_explode_dart fallback
  Future<List<Track>> getPlaylistTracks(String playlistId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedPlaylistTracks(playlistId);
      if (cached != null && cached.isNotEmpty) {
        debugPrint(
            'YtmSearchService: Loaded ${cached.length} tracks from cache for $playlistId');
        return cached;
      }
    }

    List<Track> fetchedTracks = [];

    // 1. Try YouTube Music Innertube API
    try {
      final ytmTracks = await _getTracksFromYtMusic(playlistId);
      if (ytmTracks.isNotEmpty) {
        debugPrint(
            'YtmSearchService: Fetched ${ytmTracks.length} tracks via YTM Innertube');
        fetchedTracks = ytmTracks;
      }
    } catch (e) {
      debugPrint('YtmSearchService YtMusic API error: $e');
    }

    // 2. Try native yt-dlp on Android
    if (fetchedTracks.isEmpty) {
      try {
        if (Platform.isAndroid) {
          final nativeTracks = await _getTracksFromNativeDownloader(playlistId);
          if (nativeTracks.isNotEmpty) {
            debugPrint(
                'YtmSearchService: Fetched ${nativeTracks.length} tracks via native downloader');
            fetchedTracks = nativeTracks;
          }
        }
      } catch (e) {
        debugPrint('YtmSearchService native downloader error: $e');
      }
    }

    // 3. Fallback to youtube_explode_dart
    if (fetchedTracks.isEmpty) {
      try {
        final ytExplodeTracks = await _getTracksFromYoutubeExplode(playlistId);
        if (ytExplodeTracks.isNotEmpty) {
          debugPrint(
              'YtmSearchService: Fetched ${ytExplodeTracks.length} tracks via youtube_explode_dart');
          fetchedTracks = ytExplodeTracks;
        }
      } catch (e) {
        debugPrint('YtmSearchService youtube_explode_dart error: $e');
      }
    }

    if (fetchedTracks.isNotEmpty) {
      await _cachePlaylistTracks(playlistId, fetchedTracks);
      return fetchedTracks;
    }

    return [];
  }

  Future<List<Track>> _getTracksFromYtMusic(String playlistId) async {
    final cleanId = playlistId.replaceAll('VL', '');
    final browseId = 'VL$cleanId';

    final response = await http.post(
      Uri.parse(
          'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': _userAgent,
        'Referer': 'https://music.youtube.com/',
      },
      body: jsonEncode({
        'context': _buildContext(),
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
              final runs = flexColumns[0]
                      ?['musicResponsiveListItemFlexColumnRenderer']?['text']
                  ?['runs'] as List<dynamic>?;
              if (runs != null && runs.isNotEmpty) {
                title = runs.map((e) => e['text']).join();
              }
            }
            if (flexColumns.length > 1) {
              final runs = flexColumns[1]
                      ?['musicResponsiveListItemFlexColumnRenderer']?['text']
                  ?['runs'] as List<dynamic>?;
              if (runs != null && runs.isNotEmpty) {
                artist = runs.map((e) => e['text']).join();
              }
            }

            final fixedColumns = r['fixedColumns'] as List<dynamic>? ?? [];
            if (fixedColumns.isNotEmpty) {
              final runs = fixedColumns[0]
                      ?['musicResponsiveListItemFixedColumnRenderer']?['text']
                  ?['runs'] as List<dynamic>?;
              if (runs != null && runs.isNotEmpty) {
                final durStr = runs.first['text'] as String?;
                duration = _parseDuration(durStr);
              }
            }

            String? thumbUrl;
            final thumbs = r['thumbnail']?['musicThumbnailRenderer']
                ?['thumbnail']?['thumbnails'] as List<dynamic>?;
            if (thumbs != null && thumbs.isNotEmpty) {
              thumbUrl = thumbs.last['url'] as String?;
            }

            results.add(
              Track(
                id: videoId,
                title: title,
                artist: artist,
                webUrl: 'https://www.youtube.com/watch?v=$videoId',
                duration: duration,
                artworkPath: thumbUrl,
              ),
            );
          }
        }
        for (final val in obj.values) {
          extractFromRenderers(val);
        }
      } else if (obj is List) {
        for (final item in obj) {
          extractFromRenderers(item);
        }
      }
    }

    extractFromRenderers(json);

    // Support continuation tokens for long playlists
    var token = _extractContinuationToken(json);
    var iterations = 0;
    while (token != null && token.isNotEmpty && iterations < 10) {
      iterations++;
      final continuationTracks = await _fetchContinuation(token, seenIds);
      if (continuationTracks.isEmpty) break;
      results.addAll(continuationTracks);
      token = _lastContinuationToken;
    }

    return results;
  }

  String? _lastContinuationToken;

  Future<List<Track>> _fetchContinuation(
      String token, Set<String> seenIds) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://music.youtube.com/youtubei/v1/browse?continuation=$token&prettyPrint=false'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': _userAgent,
          'Referer': 'https://music.youtube.com/',
        },
        body: jsonEncode({
          'context': _buildContext(),
        }),
      );

      if (response.statusCode != 200) {
        _lastContinuationToken = null;
        return [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final moreTracks = <Track>[];

      void extractFromContinuation(dynamic obj) {
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
                final runs = flexColumns[0]
                        ?['musicResponsiveListItemFlexColumnRenderer']?['text']
                    ?['runs'] as List<dynamic>?;
                if (runs != null && runs.isNotEmpty) {
                  title = runs.map((e) => e['text']).join();
                }
              }
              if (flexColumns.length > 1) {
                final runs = flexColumns[1]
                        ?['musicResponsiveListItemFlexColumnRenderer']?['text']
                    ?['runs'] as List<dynamic>?;
                if (runs != null && runs.isNotEmpty) {
                  artist = runs.map((e) => e['text']).join();
                }
              }

              final fixedColumns = r['fixedColumns'] as List<dynamic>? ?? [];
              if (fixedColumns.isNotEmpty) {
                final runs = fixedColumns[0]
                        ?['musicResponsiveListItemFixedColumnRenderer']?['text']
                    ?['runs'] as List<dynamic>?;
                if (runs != null && runs.isNotEmpty) {
                  final durStr = runs.first['text'] as String?;
                  duration = _parseDuration(durStr);
                }
              }

              String? thumbUrl;
              final thumbs = r['thumbnail']?['musicThumbnailRenderer']
                  ?['thumbnail']?['thumbnails'] as List<dynamic>?;
              if (thumbs != null && thumbs.isNotEmpty) {
                thumbUrl = thumbs.last['url'] as String?;
              }

              moreTracks.add(
                Track(
                  id: videoId,
                  title: title,
                  artist: artist,
                  webUrl: 'https://www.youtube.com/watch?v=$videoId',
                  duration: duration,
                  artworkPath: thumbUrl,
                ),
              );
            }
          }
          for (final val in obj.values) {
            extractFromContinuation(val);
          }
        } else if (obj is List) {
          for (final item in obj) {
            extractFromContinuation(item);
          }
        }
      }

      extractFromContinuation(json);
      _lastContinuationToken = _extractContinuationToken(json);
      return moreTracks;
    } catch (e) {
      debugPrint('YtmSearchService continuation error: $e');
      _lastContinuationToken = null;
      return [];
    }
  }

  String? _extractContinuationToken(Map<String, dynamic> json) {
    try {
      final continuations = _findKeyRecursive(json, 'continuations');
      if (continuations is List && continuations.isNotEmpty) {
        final c = continuations.first;
        final token = c['nextContinuationData']?['continuation'] ??
            c['reloadContinuationData']?['continuation'];
        if (token != null) return token as String;
      }
    } catch (_) {}
    return null;
  }

  dynamic _findKeyRecursive(dynamic obj, String targetKey) {
    if (obj is Map) {
      if (obj.containsKey(targetKey)) return obj[targetKey];
      for (final val in obj.values) {
        final res = _findKeyRecursive(val, targetKey);
        if (res != null) return res;
      }
    } else if (obj is List) {
      for (final item in obj) {
        final res = _findKeyRecursive(item, targetKey);
        if (res != null) return res;
      }
    }
    return null;
  }

  Future<List<Track>> _getTracksFromNativeDownloader(String playlistId) async {
    try {
      final downloader = AndroidDownloaderService();
      final url = 'https://www.youtube.com/playlist?list=$playlistId';
      final playlist = await downloader.fetchPlaylistMetadata(url);

      if (playlist != null && playlist.entries.isNotEmpty) {
        return playlist.entries.map((entry) {
          final dur =
              entry.duration > 0 ? Duration(seconds: entry.duration) : null;
          return Track(
            id: entry.id,
            title: entry.title,
            artist: entry.uploader ?? 'Unknown Artist',
            webUrl: entry.url,
            duration: dur,
            artworkPath: entry.bestThumbnailUrl,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('YtmSearchService native downloader error: $e');
    }
    return [];
  }

  Future<List<Track>> _getTracksFromYoutubeExplode(String playlistId) async {
    try {
      final playlist = await _yt.playlists.get(playlistId);
      final tracks = <Track>[];
      await for (final video in _yt.playlists.getVideos(playlist.id)) {
        tracks.add(
          Track(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            webUrl: video.url,
            duration: video.duration,
            artworkPath: video.thumbnails.highResUrl,
          ),
        );
      }
      return tracks;
    } catch (e) {
      debugPrint('YtmSearchService youtube_explode fallback error: $e');
      return [];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Duration? _parseDuration(String? str) {
    if (str == null || str.trim().isEmpty) return null;
    final clean = str.trim();
    final parts = clean.split(':');
    try {
      if (parts.length == 2) {
        final min = int.parse(parts[0]);
        final sec = int.parse(parts[1]);
        return Duration(minutes: min, seconds: sec);
      } else if (parts.length == 3) {
        final hr = int.parse(parts[0]);
        final min = int.parse(parts[1]);
        final sec = int.parse(parts[2]);
        return Duration(hours: hr, minutes: min, seconds: sec);
      }
    } catch (_) {}
    return null;
  }

  static dynamic _nav(dynamic root, List<dynamic> path) {
    dynamic current = root;
    for (final segment in path) {
      if (current == null) return null;
      if (segment is String && current is Map) {
        current = current[segment];
      } else if (segment is int && current is List) {
        if (segment < 0 || segment >= current.length) return null;
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  static String? _extractText(dynamic textObj) {
    if (textObj == null) return null;
    if (textObj is Map) {
      final runs = textObj['runs'] as List?;
      if (runs != null && runs.isNotEmpty) {
        return runs
            .whereType<Map<String, dynamic>>()
            .map((r) => r['text'] as String? ?? '')
            .join();
      }
      final simpleText = textObj['simpleText'] as String?;
      if (simpleText != null) return simpleText;
    }
    return null;
  }

  static String? _bestThumb(List<dynamic> thumbnails) {
    if (thumbnails.isEmpty) return null;
    final last = thumbnails.last as Map<String, dynamic>?;
    final url = last?['url'] as String?;
    if (url != null && url.startsWith('//')) return 'https:$url';
    return url;
  }
}
