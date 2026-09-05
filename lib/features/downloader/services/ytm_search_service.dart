import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/ytm_search_result.dart';

/// Bridge to the YouTube Music internal search API — the same endpoint
/// that the music.youtube.com website itself uses (replicated from ytmusicapi).
///
/// No API key registration needed. No quota system. No new packages.
/// Makes a single POST per search, exactly as ytmusicapi does in Python.
class YtMusicSearchService {
  YtMusicSearchService._();
  static final YtMusicSearchService instance = YtMusicSearchService._();

  // ── API constants (from ytmusicapi/constants.py) ────────────────────────────
  static const String _baseUrl = 'https://music.youtube.com/youtubei/v1/';
  static const String _apiKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  // ── Filter params (base64 encoded filter tokens from ytmusicapi) ────────────
  // These are the exact params the website sends for each category filter.
  static const String _paramsSongs = 'EgWKAQIIAWoKEAoQAxAEEAkQBQ%3D%3D';
  static const String _paramsPlaylists = 'EgWKAQIoAWoKEAoQAxAEEAkQBQ%3D%3D';
  static const String _paramsAlbums = 'EgWKAQIYAWoKEAoQAxAEEAkQBQ%3D%3D';
  static const String _paramsVideos = 'EgWKAQIQAWoKEAoQAxAEEAkQBQ%3D%3D';

  // ── Client context body ──────────────────────────────────────────────────────
  static Map<String, dynamic> _buildContext() => {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20240101.01.00',
          'hl': 'en',
          'gl': 'US',
          'userAgent': _userAgent,
        }
      };

  // ── Core HTTP call ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body, {
    String? params,
  }) async {
    try {
      final queryParams = 'alt=json&key=$_apiKey${params != null ? '&$params' : ''}';
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
        debugPrint('YTMusicSearch: HTTP ${response.statusCode}');
        return null;
      }

      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('YTMusicSearch._post error: $e');
      return null;
    }
  }

  // ── Public search methods ────────────────────────────────────────────────────

  /// Search songs on YouTube Music.
  Future<List<YtmSearchResult>> searchSongs(String query) async {
    return _search(query, params: _paramsSongs, type: 'song');
  }

  /// Search playlists (community + featured) on YouTube Music.
  Future<List<YtmSearchResult>> searchPlaylists(String query) async {
    return _search(query, params: _paramsPlaylists, type: 'playlist');
  }

  /// Search albums on YouTube Music.
  Future<List<YtmSearchResult>> searchAlbums(String query) async {
    return _search(query, params: _paramsAlbums, type: 'album');
  }

  /// Search videos on YouTube Music.
  Future<List<YtmSearchResult>> searchVideos(String query) async {
    return _search(query, params: _paramsVideos, type: 'video');
  }

  /// Combined search across all types (default YTM behaviour).
  Future<List<YtmSearchResult>> searchAll(String query) async {
    return _search(query, params: null, type: null);
  }

  Future<List<YtmSearchResult>> _search(
    String query, {
    String? params,
    String? type,
  }) async {
    if (query.trim().isEmpty) return [];

    final body = <String, dynamic>{
      'context': _buildContext(),
      'query': query.trim(),
      if (params != null) 'params': Uri.decodeQueryComponent(params),
    };

    final json = await _post('search', body, params: params);
    if (json == null) return [];

    try {
      return _parseResults(json, expectedType: type);
    } catch (e) {
      debugPrint('YTMusicSearch._parseResults error: $e');
      return [];
    }
  }

  // ── JSON Parsing ─────────────────────────────────────────────────────────────

  List<YtmSearchResult> _parseResults(
    Map<String, dynamic> json, {
    String? expectedType,
  }) {
    final results = <YtmSearchResult>[];

    // Navigate to the shelf contents
    final tabs = _nav(json,
        ['contents', 'tabbedSearchResultsRenderer', 'tabs']) as List?;
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

      // Each section is a shelf (musicShelfRenderer)
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

    // Extract title from first flex column
    final title = _extractText(
      _nav(renderer, [
        'flexColumns',
        0,
        'musicResponsiveListItemFlexColumnRenderer',
        'text',
      ]),
    );
    if (title == null || title.isEmpty) return null;

    // Thumbnail
    final thumbnails = _nav(renderer,
        ['thumbnail', 'musicThumbnailRenderer', 'thumbnail', 'thumbnails']) as List?;
    final thumbUrl = thumbnails != null && thumbnails.isNotEmpty
        ? _bestThumb(thumbnails)
        : null;

    // Second flex column has artist + type + duration info
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
      // Parse runs: [type, ' • ', artist, ' • ', album/year, ' • ', duration]
      final texts = col2
          .whereType<Map<String, dynamic>>()
          .map((r) => r['text'] as String? ?? '')
          .where((t) => t.trim().isNotEmpty && t.trim() != '•')
          .toList();

      // Detect type from first run if it matches known labels
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
          // track count may appear as "32 songs"
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
          // Fallback: treat first run as artist if it's not a type label
          artist = texts[0];
          if (texts.length > 1) {
            final last = texts.last;
            // Duration looks like "3:45"
            if (RegExp(r'^\d+:\d+$').hasMatch(last)) duration = last;
          }
        }
      }
    }

    detectedType ??= 'song';

    // Navigation endpoint to build URL
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

    // Try browse endpoint for playlists/albums
    final browseEndpoint =
        _nav(renderer, ['navigationEndpoint', 'browseEndpoint'])
            as Map<String, dynamic>?;
    final browseId = browseEndpoint?['browseId'] as String?;

    // Also look in the title runs for navigation
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

    // Build the URL
    String url = '';
    String? finalBrowseId = titleBrowseId;

    if (detectedType == 'playlist' || detectedType == 'album') {
      if (finalBrowseId != null) {
        // browseId for playlists starts with VL, strip it to get playlist ID
        final listId = finalBrowseId.startsWith('VL')
            ? finalBrowseId.substring(2)
            : finalBrowseId;
        url = 'https://music.youtube.com/playlist?list=$listId';
      } else if (titlePlaylistId != null) {
        url = 'https://music.youtube.com/playlist?list=$titlePlaylistId';
      }
    } else {
      // Song / video
      final vid = titleVideoId;
      if (vid != null) {
        url = 'https://music.youtube.com/watch?v=$vid';
        if (titlePlaylistId != null) {
          url += '&list=$titlePlaylistId';
        }
      }
    }

    if (url.isEmpty) return null;

    return YtmSearchResult(
      type: detectedType,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      thumbnailUrl: thumbUrl,
      url: url,
      browseId: finalBrowseId,
      videoId: titleVideoId,
      trackCount: trackCount,
    );
  }

  // ── Navigation helpers ───────────────────────────────────────────────────────

  static dynamic _nav(dynamic obj, List<dynamic> keys) {
    dynamic cur = obj;
    for (final key in keys) {
      if (cur == null) return null;
      if (key is int) {
        if (cur is! List || key >= cur.length) return null;
        cur = cur[key];
      } else {
        if (cur is! Map) return null;
        cur = cur[key];
      }
    }
    return cur;
  }

  static String? _extractText(dynamic textObj) {
    if (textObj == null) return null;
    if (textObj is Map) {
      final runs = textObj['runs'] as List?;
      if (runs != null && runs.isNotEmpty) {
        return runs
            .whereType<Map>()
            .map((r) => r['text'] as String? ?? '')
            .join('');
      }
      return textObj['simpleText'] as String?;
    }
    return null;
  }

  static String? _bestThumb(List thumbs) {
    // Pick the highest-width thumbnail available
    Map<String, dynamic>? best;
    int bestW = 0;
    for (final t in thumbs.whereType<Map<String, dynamic>>()) {
      final w = (t['width'] as num?)?.toInt() ?? 0;
      if (w > bestW) {
        bestW = w;
        best = t;
      }
    }
    return best?['url'] as String?;
  }
}
