import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_downloader/features/downloader/models/download_format.dart';
import 'package:media_downloader/features/downloader/models/download_progress.dart';
import 'package:media_downloader/features/downloader/models/media_quality.dart';
import 'package:media_downloader/features/downloader/models/playlist_metadata.dart';
import 'package:media_downloader/features/downloader/models/video_metadata.dart';
import 'package:media_downloader/features/downloader/screens/downloader_screen.dart';
import 'package:media_downloader/features/downloader/services/downloader_service.dart';

class FakeDownloaderService implements DownloaderService {
  final StreamController<DownloadProgress> _controller =
      StreamController<DownloadProgress>.broadcast();
  bool cancelled = false;
  bool autoFinish = true;
  VideoQuality? lastVideoQuality;
  AudioQuality? lastAudioQuality;

  @override
  Stream<DownloadProgress> download({
    required String url,
    required DownloadFormat format,
    VideoQuality videoQuality = VideoQuality.best,
    AudioQuality audioQuality = AudioQuality.k320,
    String? destinationDirectory,
  }) {
    cancelled = false;
    lastVideoQuality = videoQuality;
    lastAudioQuality = audioQuality;
    Future.microtask(() async {
      _controller.add(DownloadProgress.preparing());
      await Future.delayed(const Duration(milliseconds: 50));
      if (!cancelled) {
        _controller.add(
          const DownloadProgress(
            status: DownloadStatus.downloading,
            progress: 0.5,
            percentage: '50.0%',
            speed: '3.5MiB/s',
            eta: '00:05',
            title: 'Sample Test Media',
          ),
        );
        if (autoFinish) {
          await Future.delayed(const Duration(milliseconds: 50));
          if (!cancelled) {
            _controller.add(
              DownloadProgress.completed(
                outputFilePath: 'C:\\Users\\test\\Downloads\\sample.mp4',
                title: 'Sample Test Media',
              ),
            );
          }
        }
      }
    });
    return _controller.stream;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    _controller.add(DownloadProgress.cancelled(title: 'Sample Test Media'));
  }

  @override
  Future<VideoMetadata?> fetchMetadata(String url) async {
    return const VideoMetadata(
      id: 'dQw4w9WgXcQ',
      title: 'Sample Test Media',
      uploader: 'Test Channel',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      durationSeconds: 212,
      videoFormats: [
        AvailableFormat(
          formatId: '1080',
          resolutionLabel: '1080p',
          height: 1080,
          totalSizeBytes: 62117540,
          formattedSize: '59.2 MB',
        ),
        AvailableFormat(
          formatId: '720',
          resolutionLabel: '720p',
          height: 720,
          totalSizeBytes: 32966378,
          formattedSize: '31.4 MB',
        ),
      ],
      audioSizeBytes: 8195011,
    );
  }

  @override
  Future<PlaylistMetadata?> fetchPlaylistMetadata(String url) async {
    return const PlaylistMetadata(
      id: 'PL12345',
      title: 'Sample Test Playlist',
      itemCount: 2,
      entries: [
        PlaylistEntry(
            id: '1',
            title: 'Track 1',
            duration: 180,
            url: 'https://youtube.com/watch?v=1'),
        PlaylistEntry(
            id: '2',
            title: 'Track 2',
            duration: 200,
            url: 'https://youtube.com/watch?v=2'),
      ],
    );
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, String?>> getBackendInfo() async => {
        'ytDlpPath': 'test/yt-dlp.exe',
        'ffmpegPath': 'test/ffmpeg.exe',
      };
}

void main() {
  testWidgets('DownloaderScreen renders clean initial minimalist layout',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DownloaderScreen(),
      ),
    );

    // Verify brand name (no duplicate texts!)
    expect(find.text('Infyn DL'), findsOneWidget);

    // Verify input hint
    expect(find.textContaining('Paste YouTube link'), findsOneWidget);

    // Verify initial clean state: Quick Guide is removed
    expect(find.text('Quick Guide'), findsNothing);

    // Buttons are clean and hidden initially until link is fetched
    expect(find.text('MP3'), findsNothing);
    expect(find.text('MP4'), findsNothing);
  });

  testWidgets(
      'Enters valid URL, fetches metadata, and displays formats with download button',
      (WidgetTester tester) async {
    final fakeService = FakeDownloaderService();

    await tester.pumpWidget(
      MaterialApp(
        home: DownloaderScreen(downloaderService: fakeService),
      ),
    );

    // Enter valid URL
    final inputFinder = find.byType(TextField);
    await tester.enterText(
        inputFinder, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    await tester.pump();

    // Advance debounce timer (450ms) to trigger fetchMetadata
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Video details, format selector, and download button appear
    expect(find.text('Sample Test Media'), findsOneWidget);
    expect(find.text('MP4'), findsOneWidget);
    expect(find.text('MP3'), findsOneWidget);
    expect(find.byKey(const Key('download_action_button')), findsOneWidget);
  });

  testWidgets('Fetches metadata, triggers download, and observes live progress',
      (WidgetTester tester) async {
    final fakeService = FakeDownloaderService();

    await tester.pumpWidget(
      MaterialApp(
        home: DownloaderScreen(downloaderService: fakeService),
      ),
    );

    // Enter URL and wait for metadata
    final inputFinder = find.byType(TextField);
    await tester.enterText(
        inputFinder, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Tap Download
    final downloadBtn = find.byKey(const Key('download_action_button'));
    await tester.ensureVisible(downloadBtn);
    await tester.tap(downloadBtn);
    await tester.pump();

    // Verify progress card appears
    final progressCard = find.byKey(const Key('download_progress_card'));
    await tester.ensureVisible(progressCard);
    expect(progressCard, findsOneWidget);

    // Advance timers for fake progress events
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.textContaining('50.0%'), findsOneWidget);

    // Advance to completed
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(find.text('Download Completed'), findsOneWidget);
  });

  testWidgets('Cancels active download from progress card',
      (WidgetTester tester) async {
    final fakeService = FakeDownloaderService()..autoFinish = false;

    await tester.pumpWidget(
      MaterialApp(
        home: DownloaderScreen(downloaderService: fakeService),
      ),
    );

    // Enter valid URL and fetch
    final inputFinder = find.byType(TextField);
    await tester.enterText(
        inputFinder, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Tap Download
    final downloadBtn = find.byKey(const Key('download_action_button'));
    await tester.ensureVisible(downloadBtn);
    await tester.tap(downloadBtn);
    await tester.pump();

    // Advance to downloading state
    await tester.pump(const Duration(milliseconds: 60));
    final cancelFinder = find.text('Cancel Download');
    expect(cancelFinder, findsOneWidget);
    await tester.ensureVisible(cancelFinder);
    await tester.pump();

    // Tap Cancel
    await tester.tap(cancelFinder);
    await tester.pumpAndSettle();

    expect(fakeService.cancelled, isTrue);
    expect(find.text('Download Cancelled'), findsOneWidget);
  });
}
