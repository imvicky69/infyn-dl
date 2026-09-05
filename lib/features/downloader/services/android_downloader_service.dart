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
///
/// KEY DESIGN: A **single persistent** EventChannel subscription is kept alive
/// for the lifetime of this service instance. All per-download [StreamController]s
/// are stored in [_controllers] keyed by download ID. Native events are routed
/// to the correct controller — this is mandatory because each new call to
/// [EventChannel.receiveBroadcastStream] replaces the Kotlin-side EventSink,
/// causing all previously-started downloads to stop receiving progress events.
class AndroidDownloaderService implements DownloaderService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.media_downloader/downloader_methods');
  static const EventChannel _eventChannel =
      EventChannel('com.example.media_downloader/downloader_events');

  static int _idCounter = 0;

  /// Active download controllers keyed by downloadId.
  final Map<String, StreamController<DownloadProgress>> _controllers = {};

  /// Single persistent subscription to the native EventChannel.
  /// Kept alive as long as any download is active.
  StreamSubscription? _globalSubscription;

  /// Ensures the global event subscription is alive. Called before each download.
  void _ensureGlobalSubscription() {
    if (_globalSubscription != null) return;
    _globalSubscription = _eventChannel.receiveBroadcastStream().listen(
      _routeNativeEvent,
      onError: (err) {
        // On global error, fail all active downloads
        final ids = List<String>.from(_controllers.keys);
        for (final id in ids) {
          final ctrl = _controllers.remove(id);
          if (ctrl != null && !ctrl.isClosed) {
            ctrl.add(DownloadProgress.failed(err.toString()));
            ctrl.close();
          }
        }
        _globalSubscription = null;
      },
      onDone: () {
        _globalSubscription = null;
      },
    );
  }

  /// Routes a raw native event map to the matching per-download controller.
  void _routeNativeEvent(dynamic rawEvent) {
    if (rawEvent is! Map) return;
    final event = rawEvent.cast<String, dynamic>();
    final id = event['id'] as String?;
    if (id == null) return;

    final ctrl = _controllers[id];
    if (ctrl == null || ctrl.isClosed) return;

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
        ctrl.add(DownloadProgress.preparing());
        break;

      case 'downloading':
        ctrl.add(DownloadProgress(
          status: DownloadStatus.downloading,
          progress: progressRatio,
          percentage: percentage,
          speed: speed,
          eta: eta,
          totalSize: totalSize,
          title: title,
          rawLog: rawLog ?? '',
        ));
        break;

      case 'processing':
        ctrl.add(DownloadProgress(
          status: DownloadStatus.processing,
          progress: 0.99,
          percentage: '99%',
          title: title,
          rawLog: rawLog ?? '',
        ));
        break;

      case 'completed':
        _controllers.remove(id);
        ctrl.add(DownloadProgress.completed(
          outputFilePath: path ?? '',
          title: title,
        ));
        ctrl.close();
        _pruneSubscriptionIfIdle();
        break;

      case 'failed':
        _controllers.remove(id);
        ctrl.add(DownloadProgress.failed(
          error ?? 'Download failed on device',
          title: title,
        ));
        ctrl.close();
        _pruneSubscriptionIfIdle();
        break;

      case 'cancelled':
        _controllers.remove(id);
        ctrl.add(DownloadProgress.cancelled(title: title));
        ctrl.close();
        _pruneSubscriptionIfIdle();
        break;
    }
  }

  /// Cancels the global subscription when no more downloads are active,
  /// freeing the native EventSink.
  void _pruneSubscriptionIfIdle() {
    if (_controllers.isEmpty) {
      _globalSubscription?.cancel();
      _globalSubscription = null;
    }
  }

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

  Future<String?> updateEngine() async {
    try {
      final result = await _methodChannel.invokeMethod<String>('updateEngine');
      return result;
    } catch (e) {
      debugPrint('AndroidDownloaderService.updateEngine error: $e');
      return null;
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
    final downloadId =
        '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

    var cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    final controller = StreamController<DownloadProgress>();
    _controllers[downloadId] = controller;

    // Ensure we have one persistent event pipe BEFORE starting the download,
    // so no events are missed between start and the first listen.
    _ensureGlobalSubscription();

    // Emit preparing immediately so the UI shows activity right away
    controller.add(DownloadProgress.preparing());

    controller.onCancel = () {
      _controllers.remove(downloadId);
      _cancelSpecific(downloadId);
      _pruneSubscriptionIfIdle();
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
        _controllers.remove(downloadId);
        controller.add(DownloadProgress.failed(err.toString()));
        controller.close();
        _pruneSubscriptionIfIdle();
      }
      return null;
    });

    return controller.stream;
  }

  Future<void> _cancelSpecific(String downloadId) async {
    try {
      await _methodChannel
          .invokeMethod<bool>('cancelDownload', {'id': downloadId});
    } catch (_) {}
  }

  @override
  Future<void> cancel() async {
    final ids = List<String>.from(_controllers.keys);
    for (final id in ids) {
      final ctrl = _controllers.remove(id);
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(DownloadProgress.cancelled());
        ctrl.close();
      }
    }
    _globalSubscription?.cancel();
    _globalSubscription = null;

    try {
      await _methodChannel.invokeMethod<bool>('cancelAll');
    } catch (_) {
      for (final id in ids) {
        try {
          await _methodChannel
              .invokeMethod<bool>('cancelDownload', {'id': id});
        } catch (_) {}
      }
    }
  }
}
