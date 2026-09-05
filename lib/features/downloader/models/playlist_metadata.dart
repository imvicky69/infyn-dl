/// Represents a single video or track inside a YouTube / YouTube Music playlist.
class PlaylistEntry {
  final String id;
  final String title;
  final int duration;
  final String url;
  final String? uploader;
  final String? thumbnailUrl;

  const PlaylistEntry({
    required this.id,
    required this.title,
    required this.duration,
    required this.url,
    this.uploader,
    this.thumbnailUrl,
  });

  String get formattedDuration {
    if (duration <= 0) return '';
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Returns the best available thumbnail URL for this entry.
  /// Priority: stored thumbnailUrl → maxresdefault → hqdefault from YouTube.
  String? get bestThumbnailUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    if (id.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$id/maxresdefault.jpg';
    }
    return null;
  }

  factory PlaylistEntry.fromJson(Map<String, dynamic> json) {
    final entryId = json['id'] as String? ?? '';
    final rawUrl = json['url'] as String?;
    final resolvedUrl = (rawUrl != null && rawUrl.isNotEmpty)
        ? (rawUrl.startsWith('http')
            ? rawUrl
            : 'https://www.youtube.com/watch?v=$rawUrl')
        : 'https://www.youtube.com/watch?v=$entryId';

    // Best thumbnail: prefer explicit thumbnail field, then best from thumbnails array
    String? thumbUrl = json['thumbnail'] as String?;
    if ((thumbUrl == null || thumbUrl.isEmpty) && json['thumbnails'] is List) {
      final thumbs = (json['thumbnails'] as List).whereType<Map<String, dynamic>>().toList();
      // Pick highest resolution (prefer maxresdefault or largest width)
      thumbs.sort((a, b) {
        final wa = (a['width'] as num?)?.toInt() ?? 0;
        final wb = (b['width'] as num?)?.toInt() ?? 0;
        return wb.compareTo(wa);
      });
      thumbUrl = thumbs.isNotEmpty ? thumbs.first['url'] as String? : null;
    }
    // Fall back to standard YouTube hqdefault if no thumbnail in metadata
    if ((thumbUrl == null || thumbUrl.isEmpty) && entryId.isNotEmpty) {
      thumbUrl = 'https://i.ytimg.com/vi/$entryId/hqdefault.jpg';
    }

    return PlaylistEntry(
      id: entryId,
      title: json['title'] as String? ?? 'Untitled Track',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      url: resolvedUrl,
      uploader: json['uploader'] as String? ?? json['channel'] as String?,
      thumbnailUrl: thumbUrl,
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
