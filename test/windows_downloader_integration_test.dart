import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_downloader/core/utils/process_path_resolver.dart';
import 'package:media_downloader/features/downloader/models/download_format.dart';
import 'package:media_downloader/features/downloader/models/download_progress.dart';
import 'package:media_downloader/features/downloader/services/windows_downloader_service.dart';

void main() {
  const testYouTubeUrl = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';

  group('WindowsDownloaderService Integration Tests', () {
    late WindowsDownloaderService service;
    late Directory tempDownloadDir;

    setUp(() async {
      service = WindowsDownloaderService();
      tempDownloadDir =
          await Directory.systemTemp.createTemp('media_downloader_test_');
    });

    tearDown(() async {
      if (await tempDownloadDir.exists()) {
        try {
          await tempDownloadDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('yt-dlp and FFmpeg executables are detected locally', () async {
      final isAvailable = await service.isAvailable();
      expect(isAvailable, isTrue, reason: 'yt-dlp.exe must be found');

      final backendInfo = await service.getBackendInfo();
      expect(backendInfo['ytDlpPath'], isNotNull);
      expect(File(backendInfo['ytDlpPath']!).existsSync(), isTrue);

      final ffmpegPath = await ProcessPathResolver.resolveFfmpegPath();
      expect(ffmpegPath, isNotNull, reason: 'ffmpeg.exe must be found');
      expect(File(ffmpegPath!).existsSync(), isTrue);
    });

    test(
        'Downloads public domain YouTube clip, tracks progress, and creates file',
        () async {
      final updates = <DownloadProgress>[];

      await for (final update in service.download(
        url: testYouTubeUrl,
        format: DownloadFormat.mp4,
        destinationDirectory: tempDownloadDir.path,
      )) {
        updates.add(update);
      }

      // Verify yt-dlp launched and emitted preparing state
      expect(updates.any((u) => u.status == DownloadStatus.preparing), isTrue);

      // Verify download progress was parsed
      final downloadUpdates =
          updates.where((u) => u.status == DownloadStatus.downloading).toList();
      expect(downloadUpdates.isNotEmpty, isTrue);

      // Verify completion
      final finalUpdate = updates.last;
      expect(finalUpdate.status, equals(DownloadStatus.completed));
      expect(finalUpdate.progress, equals(1.0));

      // Verify that the output media file was actually created on disk
      final files = await tempDownloadDir.list().toList();
      final downloadedFile = files.whereType<File>().firstWhere(
            (f) => f.path.endsWith('.mp4'),
          );
      expect(await downloadedFile.exists(), isTrue);
      expect(await downloadedFile.length(), greaterThan(1000));
    },
        timeout: const Timeout(Duration(minutes: 2)),
        skip: 'Requires live YouTube connection');

    test('Cancellation immediately stops active yt-dlp download', () async {
      final updates = <DownloadProgress>[];
      bool cancelTriggered = false;

      final subscription = service
          .download(
        url: testYouTubeUrl,
        format: DownloadFormat.mp4,
        destinationDirectory: tempDownloadDir.path,
      )
          .listen((update) async {
        updates.add(update);
        if (!cancelTriggered && update.status == DownloadStatus.downloading) {
          cancelTriggered = true;
          await service.cancel();
        }
      });

      // Wait for stream to finish after cancellation
      await subscription.asFuture<void>().catchError((_) {});

      expect(updates.any((u) => u.status == DownloadStatus.cancelled), isTrue);
    },
        timeout: const Timeout(Duration(minutes: 1)),
        skip: 'Requires live YouTube connection');
  }, skip: !Platform.isWindows ? 'Requires Windows platform' : null);
}
