import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/download_format.dart';
import '../models/download_progress.dart';
import '../models/media_quality.dart';
import '../models/playlist_metadata.dart';
import '../models/video_metadata.dart';
import 'downloader_service.dart';

/// Android-native implementation of [DownloaderService] using local `yt-dlp`
/// and `ffmpeg` via Platform Channels (`MethodChannel` and `EventChannel`).
class AndroidDownloaderService implements DownloaderService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.media_downloader/downloader_methods');
  static const EventChannel _eventChannel =
      EventChannel('com.example.media_downloader/downloader_events');

  String? _activeDownloadId;

  Future<bool> hasNotificationPermission() async {
    try {
      final granted =
          await _methodChannel.invokeMethod<bool>('hasNotificationPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    try {
      final granted = await _methodChannel
          .invokeMethod<bool>('requestNotificationPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final isIgnoring = await _methodChannel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return isIgnoring ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final available = await _methodChannel.invokeMethod<bool>('isAvailable');
      return available ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, String?>> getBackendInfo() async {
    try {
      final info = await _methodChannel
          .invokeMapMethod<String, dynamic>('getBackendInfo');
      if (info == null) return {'platform': 'android'};
      return info.map((key, value) => MapEntry(key, value?.toString()));
    } catch (e) {
      return {'platform': 'android', 'error': e.toString()};
    }
  }

  @override
  Future<VideoMetadata?> fetchMetadata(String url) async {
    var cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    try {
      final jsonString = await _methodChannel.invokeMethod<String>(
        'fetchMetadata',
        {'url': cleanUrl},
      );
      if (jsonString == null || jsonString.isEmpty) return null;
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return VideoMetadata.fromJson(jsonMap);
    } catch (e) {
      debugPrint('AndroidDownloaderService.fetchMetadata error: $e');
      return null;
    }
  }

  @override
  Future<PlaylistMetadata?> fetchPlaylistMetadata(String url) async {
    var cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    try {
      final jsonString = await _methodChannel.invokeMethod<String>(
        'fetchPlaylistMetadata',
        {'url': cleanUrl},
      );
      if (jsonString == null || jsonString.isEmpty) return null;
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return PlaylistMetadata.fromJson(jsonMap);
    } catch (e) {
      debugPrint('AndroidDownloaderService.fetchPlaylistMetadata error: $e');
      return null;
    }
  }

  @override
  Stream<DownloadProgress> download({
    required String url,
    required DownloadFormat format,
    VideoQuality videoQuality = VideoQuality.best,
    AudioQuality audioQuality = AudioQuality.k320,
    String? destinationDirectory,
  }) {
    final controller = StreamController<DownloadProgress>();
    final downloadId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeDownloadId = downloadId;

    var cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    controller.add(DownloadProgress.preparing());

    StreamSubscription? subscription;

    subscription = _eventChannel.receiveBroadcastStream().listen(
      (rawEvent) {
        if (rawEvent is! Map) return;
        final event = rawEvent.cast<String, dynamic>();

        final id = event['id'] as String?;
        if (id != downloadId) return;

        final statusStr = event['status'] as String? ?? 'preparing';
        final progressRatio = (event['progress'] as num?)?.toDouble() ?? 0.0;
        final percentage = event['percentage'] as String? ??
            '${(progressRatio * 100).toInt()}%';
        final speed = event['speed'] as String?;
        final eta = event['eta'] as String?;
        final totalSize = event['totalSize'] as String?;
        final title = event['title'] as String?;
        final path = event['path'] as String?;
        final error = event['error'] as String?;
        final rawLog = event['rawLog'] as String?;

        switch (statusStr) {
          case 'preparing':
            controller.add(DownloadProgress.preparing());
            break;

          case 'downloading':
            controller.add(
              DownloadProgress(
                status: DownloadStatus.downloading,
                progress: progressRatio,
                percentage: percentage,
                speed: speed,
                eta: eta,
                totalSize: totalSize,
                title: title,
                rawLog: rawLog ?? '',
              ),
            );
            break;

          case 'processing':
            controller.add(
              DownloadProgress(
                status: DownloadStatus.processing,
                progress: 0.99,
                percentage: '99%',
                title: title,
                rawLog: rawLog ?? '',
              ),
            );
            break;

          case 'completed':
            controller.add(
              DownloadProgress.completed(
                outputFilePath: path ?? '',
                title: title,
              ),
            );
            subscription?.cancel();
            controller.close();
            break;

          case 'failed':
            controller.add(
              DownloadProgress.failed(
                error ?? 'Download failed on device',
                title: title,
              ),
            );
            subscription?.cancel();
            controller.close();
            break;

          case 'cancelled':
            controller.add(DownloadProgress.cancelled(title: title));
            subscription?.cancel();
            controller.close();
            break;
        }
      },
      onError: (err) {
        controller.add(DownloadProgress.failed(err.toString()));
        controller.close();
      },
    );

    controller.onCancel = () {
      subscription?.cancel();
      if (_activeDownloadId == downloadId) {
        cancel();
      }
    };

    // Trigger start on native Kotlin side
    _methodChannel.invokeMethod<String>('startDownload', {
      'id': downloadId,
      'url': cleanUrl,
      'format': format.name,
      'videoQuality': videoQuality.shortLabel,
      'audioQuality': audioQuality.qualityValue,
      'destinationDirectory': destinationDirectory,
    }).catchError((err) {
      if (!controller.isClosed) {
        controller.add(DownloadProgress.failed(err.toString()));
        controller.close();
      }
      return null;
    });

    return controller.stream;
  }

  @override
  Future<void> cancel() async {
    final id = _activeDownloadId;
    if (id != null) {
      try {
        await _methodChannel.invokeMethod<bool>('cancelDownload', {'id': id});
      } catch (_) {}
    }
  }
}
