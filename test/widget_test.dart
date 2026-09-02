import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_downloader/features/downloader/models/download_format.dart';
import 'package:media_downloader/features/downloader/models/download_progress.dart';
import 'package:media_downloader/features/downloader/models/media_quality.dart';
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
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, String?>> getBackendInfo() async => {
        'ytDlpPath': 'test/yt-dlp.exe',
        'ffmpegPath': 'test/ffmpeg.exe',
      };
}

void main() {
  testWidgets('MediaDownloaderApp renders essential UI elements',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DownloaderScreen(),
      ),
    );

    // Verify app title
    expect(find.text('infyn-yt'), findsWidgets);

    // Verify input hint
    expect(find.textContaining('Paste YouTube link'), findsOneWidget);

    // Verify format options
    expect(find.text('MP3'), findsOneWidget);
    expect(find.text('MP4'), findsOneWidget);

    // Verify Download action button
    expect(find.byKey(const Key('download_action_button')), findsOneWidget);

    // Verify Guide
    expect(find.text('Quick Guide'), findsOneWidget);
  });

  testWidgets('Shows error message when Download tapped without URL',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DownloaderScreen(),
      ),
    );

    // Tap Download action button
    await tester.tap(find.byKey(const Key('download_action_button')));
    await tester.pump();

    // Verify error text
    expect(find.text('Please enter or paste a YouTube URL'), findsOneWidget);
  });

  testWidgets('Switches format between MP4 and MP3',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DownloaderScreen(),
      ),
    );

    // Initially MP4 is selected
    expect(find.text(DownloadFormat.mp4.subtitle), findsOneWidget);

    // Tap MP3 card
    await tester.tap(find.text('MP3'));
    await tester.pump();

    // Now MP3 subtitle is visible
    expect(find.text(DownloadFormat.mp3.subtitle), findsOneWidget);
  });

  testWidgets('Enters valid URL, tracks progress and completes download',
      (WidgetTester tester) async {
    final fakeService = FakeDownloaderService();

    await tester.pumpWidget(
      MaterialApp(
        home: DownloaderScreen(downloaderService: fakeService),
      ),
    );

    // Enter valid URL
    final inputFinder = find.byType(TextField);
    await tester.enterText(inputFinder, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    await tester.pump();

    // Tap Download
    await tester.tap(find.byKey(const Key('download_action_button')));
    await tester.pump();

    // Verify progress card appears
    expect(find.byKey(const Key('download_progress_card')), findsOneWidget);

    // Advance timers for fake progress events
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.textContaining('50.0%'), findsOneWidget);
    expect(find.textContaining('Sample Test Media'), findsOneWidget);

    // Advance to completed
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(); // For SnackBar animation

    expect(find.text('Download Completed'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Media downloaded successfully!'), findsOneWidget);
  });

  testWidgets('Cancels active download from progress card',
      (WidgetTester tester) async {
    final fakeService = FakeDownloaderService()..autoFinish = false;

    await tester.pumpWidget(
      MaterialApp(
        home: DownloaderScreen(downloaderService: fakeService),
      ),
    );

    // Enter valid URL
    final inputFinder = find.byType(TextField);
    await tester.enterText(inputFinder, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    await tester.pump();

    // Tap Download
    await tester.tap(find.byKey(const Key('download_action_button')));
    await tester.pump();

    // Advance to downloading state
    await tester.pump(const Duration(milliseconds: 60));
    final cancelFinder = find.text('Cancel Download');
    expect(cancelFinder, findsOneWidget);
    await tester.ensureVisible(cancelFinder);
    await tester.pump();

    // Tap Cancel
    await tester.tap(cancelFinder);
    await tester.pump();

    expect(fakeService.cancelled, isTrue);
    expect(find.text('Download Cancelled'), findsOneWidget);
  });

  testWidgets('Allows selecting video quality and audio bitrate',
      (WidgetTester tester) async {
    final fakeService = FakeDownloaderService();

    await tester.pumpWidget(
      MaterialApp(
        home: DownloaderScreen(downloaderService: fakeService),
      ),
    );

    // Verify video quality pills are visible by default
    expect(find.text('Video Resolution'), findsOneWidget);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('720p'), findsOneWidget);

    // Tap 1080p
    await tester.tap(find.text('1080p'));
    await tester.pump();

    // Enter URL and trigger download
    final inputFinder = find.byType(TextField);
    await tester.enterText(inputFinder, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    await tester.pump();

    await tester.tap(find.byKey(const Key('download_action_button')));
    await tester.pump();

    expect(fakeService.lastVideoQuality, VideoQuality.p1080);

    // Wait for fake download and snackbar to settle
    await tester.pump(const Duration(seconds: 4));

    // Switch to MP3
    await tester.tap(find.text('MP3'));
    await tester.pump();

    // Verify audio quality pills are shown
    expect(find.text('Audio Bitrate'), findsOneWidget);
    expect(find.textContaining('192k'), findsOneWidget);

    // Tap 192k
    final quality192Finder = find.textContaining('192k');
    await tester.ensureVisible(quality192Finder);
    await tester.tap(quality192Finder);
    await tester.pump();

    final downloadBtnFinder = find.byKey(const Key('download_action_button'));
    await tester.ensureVisible(downloadBtnFinder);
    await tester.tap(downloadBtnFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fakeService.lastAudioQuality, AudioQuality.k192);
  });
}
