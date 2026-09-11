import '../../search/models/search_playlist_info.dart';

/// Model representing a curated playlist from the remote GitHub catalog.
class CatalogPlaylist {
  final String id;
  final String title;
  final String url; // Complete URL from YouTube or YouTube Music (or ID)
  final String description;
  final List<String> genres;
  final List<String> languages;
  final List<String> moods;
  final List<String> tags;
  final bool featured;
  final String? thumbnailUrl;
  final int? trackCount;
  final String? author;

  const CatalogPlaylist({
    required this.id,
    required this.title,
    required this.url,
    this.description = '',
    this.genres = const [],
    this.languages = const [],
    this.moods = const [],
    this.tags = const [],
    this.featured = false,
    this.thumbnailUrl,
    this.trackCount,
    this.author,
  });

  /// Extracts the playlist ID parameter from a complete YouTube/YouTube Music URL,
  /// or returns the trimmed string if already an ID.
  static String extractPlaylistId(String urlOrId) {
    final trimmed = urlOrId.trim();
    if (trimmed.isEmpty) return '';

    // If it doesn't contain slashes or query markers, treat as a raw ID
    if (!trimmed.contains('/') && !trimmed.contains('?')) {
      return trimmed;
    }

    try {
      final uri = Uri.parse(trimmed);
      final listParam = uri.queryParameters['list'];
      if (listParam != null && listParam.isNotEmpty) {
        return listParam;
      }
    } catch (_) {}

    final match = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!;
    }

    return trimmed;
  }

  /// Resolved YouTube playlist ID for API calls.
  String get youtubeId => extractPlaylistId(url);

  /// Resolved canonical YouTube playlist URL.
  String get youtubeUrl {
    final clean = url.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    return 'https://www.youtube.com/playlist?list=$clean';
  }

  /// Resolved YouTube Music playlist URL.
  String get musicYoutubeUrl =>
      'https://music.youtube.com/playlist?list=$youtubeId';

  /// Factory constructor that validates and parses a JSON map.
  /// Accepts either complete `url` (e.g. from YouTube/YouTube Music) or legacy `youtubeId`.
  /// Returns null if required fields (`id`, `title`, and `url`/`youtubeId`) are missing or empty.
  static CatalogPlaylist? fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim();
    final rawTitle = json['title']?.toString().trim();
    final rawUrl = (json['url'] ?? json['youtubeId'])?.toString().trim();

    if (rawId == null || rawId.isEmpty) return null;
    if (rawTitle == null || rawTitle.isEmpty) return null;
    if (rawUrl == null || rawUrl.isEmpty) return null;

    final normalizedUrl =
        (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))
            ? rawUrl
            : 'https://www.youtube.com/playlist?list=$rawUrl';

    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    return CatalogPlaylist(
      id: rawId,
      title: rawTitle,
      url: normalizedUrl,
      description: json['description']?.toString().trim() ?? '',
      genres: parseStringList(json['genres']),
      languages: parseStringList(json['languages']),
      moods: parseStringList(json['moods']),
      tags: parseStringList(json['tags']),
      featured: json['featured'] == true,
      thumbnailUrl: json['thumbnailUrl']?.toString().trim(),
      trackCount: (json['trackCount'] as num?)?.toInt(),
      author: json['author']?.toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'description': description,
      'genres': genres,
      'languages': languages,
      'moods': moods,
      'tags': tags,
      'featured': featured,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (trackCount != null) 'trackCount': trackCount,
      if (author != null) 'author': author,
    };
  }

  /// Converts this catalog item into a [SearchPlaylistInfo] to reuse
  /// the full-featured playlist detail and batch download screen.
  SearchPlaylistInfo toSearchPlaylistInfo() {
    return SearchPlaylistInfo(
      id: youtubeId,
      title: title,
      author: author ?? 'Infyn Curators',
      thumbnailUrl: thumbnailUrl,
      trackCount: trackCount,
      description: description,
      genres: genres,
      languages: languages,
      moods: moods,
    );
  }

  /// Subtitle for cards and listings.
  String get subtitle {
    final parts = <String>[];
    if (author != null && author!.isNotEmpty) parts.add(author!);
    if (trackCount != null && trackCount! > 0) parts.add('$trackCount tracks');
    if (genres.isNotEmpty) parts.add(genres.first);
    return parts.isNotEmpty ? parts.join(' • ') : 'Curated Playlist';
  }
}
