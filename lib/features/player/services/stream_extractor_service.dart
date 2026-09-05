import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../library/models/track.dart';
import 'media_cache_service.dart';

/// Extracts direct streaming URLs from remote platforms (e.g., YouTube Music)
/// using youtube_explode_dart for blazing fast pure-Dart extraction.
class StreamExtractorService {
  StreamExtractorService._();
  static final StreamExtractorService instance = StreamExtractorService._();

  final yt.YoutubeExplode _yt = yt.YoutubeExplode();

  /// Gets the best audio stream URL for a given track.
  /// Checks cache first to avoid waking up yt-dlp.
  Future<String?> getStreamUrl(Track track) async {
    if (track.isLocal) {
      return track.filePath;
    }

    if (track.webUrl == null || track.webUrl!.isEmpty) {
      return null;
    }

    final webUrl = track.webUrl!;

    // 1. Check cache
    final cached = MediaCacheService.instance.getStreamUrl(webUrl);
    if (cached != null) {
      return cached;
    }

    // 2. Extract via youtube_explode_dart
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(webUrl);
      
      // Get the best audio-only stream (m4a/webm)
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isNotEmpty) {
        final bestAudio = audioStreams.withHighestBitrate();
        final bestUrl = bestAudio.url.toString();
        
        // Cache it
        await MediaCacheService.instance.setStreamUrl(webUrl, bestUrl);
        return bestUrl;
      }
    } catch (e) {
      debugPrint('StreamExtractorService error for $webUrl: $e');
    }

    return null;
  }

  void dispose() {
    _yt.close();
  }
}
