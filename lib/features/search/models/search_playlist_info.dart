/// Model representing an online playlist or album found in search or curated catalog.
class SearchPlaylistInfo {
  final String id;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final int? trackCount;
  final String? description;
  final List<String> genres;
  final List<String> languages;
  final List<String> moods;

  const SearchPlaylistInfo({
    required this.id,
    required this.title,
    this.author,
    this.thumbnailUrl,
    this.trackCount,
    this.description,
    this.genres = const [],
    this.languages = const [],
    this.moods = const [],
  });

  String get subtitle {
    final parts = <String>[];
    if (author != null && author!.isNotEmpty) parts.add(author!);
    if (trackCount != null && trackCount! > 0) parts.add('$trackCount tracks');
    if (genres.isNotEmpty) parts.add(genres.first);
    return parts.isNotEmpty ? parts.join(' • ') : 'Tap to view & download';
  }
}
