/// Represents a single video or track inside a YouTube / YouTube Music playlist.
class PlaylistEntry {
  final String id;
  final String title;
  final int duration;
  final String url;
  final String? uploader;

  const PlaylistEntry({
    required this.id,
    required this.title,
    required this.duration,
    required this.url,
    this.uploader,
  });

  String get formattedDuration {
    if (duration <= 0) return '';
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory PlaylistEntry.fromJson(Map<String, dynamic> json) {
    final entryId = json['id'] as String? ?? '';
    final rawUrl = json['url'] as String?;
    final resolvedUrl = (rawUrl != null && rawUrl.isNotEmpty)
        ? (rawUrl.startsWith('http')
            ? rawUrl
            : 'https://www.youtube.com/watch?v=$rawUrl')
        : 'https://www.youtube.com/watch?v=$entryId';

    return PlaylistEntry(
      id: entryId,
      title: json['title'] as String? ?? 'Untitled Track',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      url: resolvedUrl,
      uploader: json['uploader'] as String? ?? json['channel'] as String?,
    );
  }
}

/// Represents metadata for an entire YouTube or YouTube Music playlist.
class PlaylistMetadata {
  final String id;
  final String title;
  final String? uploader;
  final int itemCount;
  final List<PlaylistEntry> entries;
  final String? webpageUrl;

  const PlaylistMetadata({
    required this.id,
    required this.title,
    this.uploader,
    required this.itemCount,
    required this.entries,
    this.webpageUrl,
  });

  factory PlaylistMetadata.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    final parsedEntries = <PlaylistEntry>[];

    for (final e in rawEntries) {
      if (e is Map<String, dynamic>) {
        parsedEntries.add(PlaylistEntry.fromJson(e));
      }
    }

    return PlaylistMetadata(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'YouTube Playlist',
      uploader: json['uploader'] as String? ?? json['channel'] as String?,
      itemCount:
          (json['playlist_count'] as num?)?.toInt() ?? parsedEntries.length,
      entries: parsedEntries,
      webpageUrl: json['webpage_url'] as String?,
    );
  }
}
