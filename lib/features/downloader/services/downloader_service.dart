import '../models/download_format.dart';
import '../models/download_progress.dart';
import '../models/media_quality.dart';
import '../models/playlist_metadata.dart';
import '../models/video_metadata.dart';

/// Platform-agnostic interface for media download operations.
///
/// Implementations (e.g. Windows, Android, macOS) handle process management
/// or platform channels independently while exposing a uniform reactive stream.
abstract class DownloaderService {
  /// Fetches available metadata, resolutions, and file sizes for a given media URL.
  Future<VideoMetadata?> fetchMetadata(String url);

  /// Fetches playlist information and list of items if the URL is a playlist.
  Future<PlaylistMetadata?> fetchPlaylistMetadata(String url);

  /// Stream that emits live progress updates during the download lifecycle.
  Stream<DownloadProgress> download({
    required String url,
    required DownloadFormat format,
    VideoQuality videoQuality = VideoQuality.best,
    AudioQuality audioQuality = AudioQuality.k192,
    String? destinationDirectory,
  });

  /// Cancels an ongoing download process immediately.
  Future<void> cancel();

  /// Validates whether the required platform tools/backends (e.g. yt-dlp, FFmpeg)
  /// are present and ready to execute.
  Future<bool> isAvailable();

  /// Gets the current resolved backend information (e.g. executable paths or versions).
  Future<Map<String, String?>> getBackendInfo();
}
