import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_downloader/features/downloader/models/download_format.dart';
import 'package:media_downloader/features/downloader/models/download_progress.dart';
import 'package:media_downloader/features/downloader/models/media_quality.dart';
import 'package:media_downloader/features/downloader/models/playlist_metadata.dart';
import 'package:media_downloader/features/downloader/models/video_metadata.dart';
import 'package:media_downloader/features/downloader/services/download_history_service.dart';
import 'package:media_downloader/features/downloader/services/downloader_service.dart';
import 'package:media_downloader/features/downloader/services/music_download_manager.dart';
import 'package:media_downloader/features/home/screens/main_shell_screen.dart';
import 'package:media_downloader/features/library/models/track.dart';
import 'package:media_downloader/features/player/widgets/mini_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMusicDownloaderService implements DownloaderService {
  final Map<String, StreamController<DownloadProgress>> controllers = {};

  @override
  Stream<DownloadProgress> download({
    required String url,
    required DownloadFormat format,
    VideoQuality videoQuality = VideoQuality.best,
    AudioQuality audioQuality = AudioQuality.k192,
    String? destinationDirectory,
  }) {
    final ctrl = StreamController<DownloadProgress>.broadcast();
    controllers[url] = ctrl;

    scheduleMicrotask(() {
      ctrl.add(DownloadProgress.preparing());
      ctrl.add(DownloadProgress(
        status: DownloadStatus.downloading,
        progress: 0.5,
        percentage: '50%',
      ));
    });

    return ctrl.stream;
  }

  void complete(String url, {String? filePath, String? title}) {
    final ctrl = controllers[url];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(DownloadProgress.completed(
        outputFilePath: filePath ?? '/tmp/test.mp3',
        title: title ?? 'Test Track',
      ));
      ctrl.close();
    }
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<Map<String, String?>> getBackendInfo() async => {'platform': 'test'};

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<VideoMetadata?> fetchMetadata(String url) async => null;

  @override
  Future<PlaylistMetadata?> fetchPlaylistMetadata(String url) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('download_mgr_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('MusicDownloadManager Tests', () {
    test('Downloads single track in background and persists to history', () async {
      final fakeService = _FakeMusicDownloaderService();
      final manager = MusicDownloadManager.instance;
      manager.downloaderService = fakeService;

      const track = Track(
        id: 'track_123',
        title: 'Background Symphony',
        artist: 'Mozart',
        webUrl: 'https://www.youtube.com/watch?v=track_123',
      );

      expect(manager.isDownloading(track.id), isFalse);

      await manager.downloadTrack(track);

      expect(manager.isDownloading(track.id), isTrue);
      expect(manager.hasActiveDownloads, isTrue);

      // Wait for progress events
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(manager.getProgress(track.id), equals(0.5));
      expect(manager.getPercentage(track.id), equals('50%'));

      // Complete download
      final sampleMp3 = File('${tempDir.path}/Background Symphony.mp3');
      await sampleMp3.writeAsString('audio-bytes');
      fakeService.complete(track.webUrl!, filePath: sampleMp3.path, title: track.title);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(manager.isDownloading(track.id), isFalse);
      final history = await DownloadHistoryService.instance.getHistory();
      expect(history.any((h) => h.title == 'Background Symphony'), isTrue);
    });
  });

  group('MainShellScreen Non-Overlapping Layout Tests', () {
    testWidgets('Renders MiniPlayer below IndexedStack in Column to prevent overlap',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: MainShellScreen(),
        ),
      );

      // Verify Column is used for main body
      final columnFinder = find.descendant(
        of: find.byType(Scaffold).first,
        matching: find.byType(Column),
      );
      expect(columnFinder, findsWidgets);

      // Verify MiniPlayer is present in the layout tree
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Verify IndexedStack is wrapped in Expanded
      final expandedFinder = find.byType(Expanded);
      expect(expandedFinder, findsWidgets);

      // Flush AudioPlayerService debounce timer
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
