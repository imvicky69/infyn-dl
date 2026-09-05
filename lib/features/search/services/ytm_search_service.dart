import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../library/models/track.dart';

/// Fast search service using youtube_explode_dart.
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

  void dispose() {
    _yt.close();
  }
}
