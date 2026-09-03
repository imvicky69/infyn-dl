import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_downloader/core/theme/app_theme.dart';
import 'package:media_downloader/features/downloader/models/download_format.dart';
import 'package:media_downloader/features/downloader/models/download_progress.dart';
import 'package:media_downloader/features/downloader/models/playlist_metadata.dart';
import 'package:media_downloader/features/downloader/models/media_quality.dart';
import 'package:media_downloader/features/downloader/models/video_metadata.dart';
import 'package:media_downloader/features/downloader/services/downloader_service.dart';
import 'package:media_downloader/features/home/screens/main_shell_screen.dart';
import 'package:media_downloader/features/settings/screens/settings_screen.dart';
import 'package:media_downloader/features/settings/services/settings_service.dart';
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

  group('SettingsService ThemeMode Tests', () {
    test('Defaults to system, updates and persists theme mode', () async {
      final service = SettingsService.instance;
      await service.init();

      expect(service.themeModeNotifier.value, isNotNull);

      await service.setThemeMode(ThemeMode.dark);
      expect(service.themeMode, ThemeMode.dark);
      expect(service.themeModeNotifier.value, ThemeMode.dark);

      await service.setThemeMode(ThemeMode.light);
      expect(service.themeMode, ThemeMode.light);
      expect(service.themeModeNotifier.value, ThemeMode.light);

      await service.setThemeMode(ThemeMode.system);
      expect(service.themeMode, ThemeMode.system);
      expect(service.themeModeNotifier.value, ThemeMode.system);
    });
  });

  group('AppColors Dynamic Theme Tests', () {
    test('Switches between light and dark palette dynamically', () {
      AppColors.isDark = false;
      expect(AppColors.background, const Color(0xFFFAFAFA));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.textPrimary, const Color(0xFF09090B));
      expect(AppColors.primary, const Color(0xFF09090B));

      AppColors.isDark = true;
      expect(AppColors.background, const Color(0xFF09090B));
      expect(AppColors.surface, const Color(0xFF141416));
      expect(AppColors.textPrimary, const Color(0xFFFAFAFA));
      expect(AppColors.primary, const Color(0xFFFAFAFA));

      // Reset
      AppColors.isDark = false;
    });
  });

  group('MainShellScreen 3-Tab Navigation Tests', () {
    testWidgets(
        'Renders 3 tabs: Downloader, Library, Settings and no Tools tab',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainShellScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Downloader'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Tools'), findsNothing);
    });
  });

  group('SettingsScreen Appearance & Web Tools Suite Tests', () {
    testWidgets('Renders Theme Mode toggle and Infyn Web Tools Suite section',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await SettingsService.instance.init();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            downloaderService: _MockDownloaderService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Appearance section
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);

      // Scroll down to Infyn Web Utilities Suite section
      await tester.scrollUntilVisible(
        find.text('INFYN WEB UTILITIES SUITE'),
        200,
      );

      // Verify Infyn Web Utilities Suite section
      expect(find.text('INFYN WEB UTILITIES SUITE'), findsOneWidget);
      expect(find.text('Infyn Browser Tools Suite'), findsOneWidget);
      expect(find.text('Launch Infyn Tools (infyn.software)'), findsOneWidget);
      expect(find.text('PDF to Image'), findsOneWidget);
      expect(find.text('Compress PDF'), findsOneWidget);
    });
  });
}

class _MockDownloaderService extends DownloaderService {
  @override
  Future<Map<String, String?>> getBackendInfo() async => {
        'ytDlpPath': '/mock/yt-dlp',
        'ffmpegPath': '/mock/ffmpeg',
        'ffmpegDir': '/mock',
      };

  @override
  Stream<DownloadProgress> download({
    required String url,
    required DownloadFormat format,
    VideoQuality videoQuality = VideoQuality.best,
    AudioQuality audioQuality = AudioQuality.k320,
    String? destinationDirectory,
  }) =>
      const Stream.empty();

  @override
  Future<VideoMetadata?> fetchMetadata(String url) async => null;

  @override
  Future<PlaylistMetadata?> fetchPlaylistMetadata(String url) async => null;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> cancel() async {}
}
