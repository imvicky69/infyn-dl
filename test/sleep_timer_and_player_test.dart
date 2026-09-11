import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infyn_dl/features/library/models/music_playlist.dart';
import 'package:infyn_dl/features/library/models/track.dart';
import 'package:infyn_dl/features/library/screens/playlist_detail_screen.dart';
import 'package:infyn_dl/features/player/services/audio_player_service.dart';
import 'package:infyn_dl/features/player/services/sleep_timer_service.dart';
import 'package:infyn_dl/features/player/widgets/mini_player.dart';
import 'package:infyn_dl/features/player/widgets/sleep_timer_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  group('SleepTimerService Unit Tests', () {
    tearDown(() {
      SleepTimerService.instance.cancelTimer();
    });

    test('Initial state is inactive with null remaining time', () {
      final service = SleepTimerService.instance;
      service.cancelTimer();

      expect(service.isRunning, isFalse);
      expect(service.remaining, isNull);
      expect(service.isEndOfTrack, isFalse);
      expect(service.fadeAudio, isTrue);
    });

    test('startTimer activates timer and sets remaining duration', () {
      final service = SleepTimerService.instance;
      const duration = Duration(minutes: 30);

      service.startTimer(duration);

      expect(service.isRunning, isTrue);
      expect(service.isEndOfTrack, isFalse);
      expect(service.remaining, isNotNull);
      expect(service.remaining!.inMinutes, closeTo(30, 1));
      expect(service.formatRemaining(service.remaining), contains('30:'));
    });

    test('addMinutes extends active timer', () {
      final service = SleepTimerService.instance;
      service.startTimer(const Duration(minutes: 15));

      final initialRemaining = service.remaining!.inSeconds;
      service.addMinutes(15);

      final newRemaining = service.remaining!.inSeconds;
      expect(newRemaining, greaterThan(initialRemaining));
      expect(service.remaining!.inMinutes, closeTo(30, 1));
    });

    test('cancelTimer resets all state and notifiers', () {
      final service = SleepTimerService.instance;
      service.startTimer(const Duration(minutes: 45));
      expect(service.isRunning, isTrue);

      service.cancelTimer();

      expect(service.isRunning, isFalse);
      expect(service.remaining, isNull);
      expect(service.isEndOfTrack, isFalse);
    });

    test('formatRemaining formats various durations correctly', () {
      final service = SleepTimerService.instance;

      expect(service.formatRemaining(null), '');
      expect(
          service.formatRemaining(const Duration(minutes: 5, seconds: 3)), '5:03');
      expect(service.formatRemaining(const Duration(hours: 1, minutes: 20)),
          '1h 20m');
    });
  });

  group('SleepTimerSheet Widget Tests', () {
    tearDown(() {
      SleepTimerService.instance.cancelTimer();
    });

    testWidgets('Renders presets, slider, and start button in inactive state',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SleepTimerService.instance.cancelTimer();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SleepTimerSheet(),
          ),
        ),
      );
      await tester.pump();

      // Check header
      expect(find.text('Sleep Timer'), findsOneWidget);

      // Check presets
      expect(find.text('15m'), findsOneWidget);
      expect(find.text('30m'), findsOneWidget);
      expect(find.text('45m'), findsOneWidget);
      expect(find.text('60m'), findsAtLeastNWidgets(1));
      expect(find.text('End of Track'), findsOneWidget);

      // Check fade-out toggle
      expect(find.text('Smooth audio fade-out'), findsOneWidget);

      // Check start button
      expect(find.textContaining('Start Sleep Timer'), findsOneWidget);
    });

    testWidgets('Renders active countdown and extension buttons when running',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(() => SleepTimerService.instance.cancelTimer());

      SleepTimerService.instance.startTimer(const Duration(minutes: 25));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SleepTimerSheet(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('+5 Min'), findsOneWidget);
      expect(find.text('+15 Min'), findsOneWidget);
      expect(find.text('Turn Off Timer'), findsOneWidget);

      // Explicitly cancel before test completes to flush periodic timer
      SleepTimerService.instance.cancelTimer();
      await tester.pump();
    });
  });

  group('PlaylistDetailScreen MiniPlayer Visibility Tests', () {
    testWidgets(
        'Renders MiniPlayer at bottom of PlaylistDetailScreen when track is active',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const track = Track(
        id: 'test-track-1',
        title: 'Test Song',
        artist: 'Test Artist',
        duration: Duration(minutes: 3, seconds: 45),
        filePath: '/storage/emulated/0/Download/infyn-dl/test.mp3',
      );

      final playlist = MusicPlaylist(
        name: 'My Liked Songs',
        tracks: [track],
      );

      // Set current track on AudioPlayerService
      AudioPlayerService.instance.currentTrack = track;

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlist: playlist,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify playlist title and track exist
      expect(find.text('My Liked Songs'), findsOneWidget);
      expect(find.text('Test Song'), findsAtLeastNWidgets(1));

      // Verify MiniPlayer is mounted in bottomNavigationBar
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Clean up track
      AudioPlayerService.instance.currentTrack = null;
    });
  });
}
