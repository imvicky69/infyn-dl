/// Represents a single search result from the YouTube Music internal API.
class YtmSearchResult {
  final String type; // 'song', 'playlist', 'album', 'artist', 'video'
  final String title;
  final String? artist;
  final String? album;
  final String? duration; // e.g. "3:45"
  final String? thumbnailUrl;
  final String url; // Direct playable / playlist URL
  final String? browseId; // For playlists/albums — prefix VL for playlist URL
  final String? videoId;
  final int? trackCount; // For playlists

  const YtmSearchResult({
    required this.type,
    required this.title,
    required this.url,
    this.artist,
    this.album,
    this.duration,
    this.thumbnailUrl,
    this.browseId,
    this.videoId,
    this.trackCount,
  });

  bool get isPlayable => url.isNotEmpty;

  String get typeLabel {
    switch (type) {
      case 'song':
        return 'Song';
      case 'playlist':
      case 'community_playlist':
      case 'featured_playlist':
        return 'Playlist';
      case 'album':
        return 'Album';
      case 'video':
        return 'Video';
      default:
        return type;
    }
  }

  String get subtitle {
    final parts = <String>[];
    if (artist != null && artist!.isNotEmpty) parts.add(artist!);
    if (album != null && album!.isNotEmpty && type == 'song') {
      parts.add(album!);
    }
    if (trackCount != null && trackCount! > 0) {
      parts.add('$trackCount tracks');
    }
    if (duration != null && duration!.isNotEmpty) parts.add(duration!);
    return parts.join(' · ');
  }
}
