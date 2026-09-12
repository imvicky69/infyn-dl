import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infyn_dl/core/theme/app_theme.dart';
import 'package:infyn_dl/features/downloader/models/download_format.dart';
import 'package:infyn_dl/features/downloader/models/download_progress.dart';
import 'package:infyn_dl/features/downloader/models/playlist_metadata.dart';
import 'package:infyn_dl/features/downloader/models/media_quality.dart';
import 'package:infyn_dl/features/downloader/models/video_metadata.dart';
import 'package:infyn_dl/features/downloader/services/downloader_service.dart';
import 'package:infyn_dl/features/home/screens/main_shell_screen.dart';
import 'package:infyn_dl/features/settings/models/app_release_info.dart';
import 'package:infyn_dl/features/settings/screens/settings_screen.dart';
import 'package:infyn_dl/features/settings/services/app_update_service.dart';
import 'package:infyn_dl/features/settings/services/settings_service.dart';
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
      expect(AppColors.logo, 'assets/logo-clear.png');

      AppColors.isDark = true;
      expect(AppColors.background, const Color(0xFF09090B));
      expect(AppColors.surface, const Color(0xFF141416));
      expect(AppColors.textPrimary, const Color(0xFFFAFAFA));
      expect(AppColors.primary, const Color(0xFFFAFAFA));
      expect(AppColors.logo, 'assets/logo-wh.png');

      // Reset
      AppColors.isDark = false;
    });
  });

  group('MainShellScreen Navigation Tests', () {
    testWidgets(
        'Renders 4 clean destinations: Music, Search, Library, Settings and no Downloader tab',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainShellScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Music'), findsAtLeastNWidgets(1));
      expect(find.text('Search'), findsAtLeastNWidgets(1));
      expect(find.text('Downloader'), findsNothing);
      expect(find.text('Library'), findsAtLeastNWidgets(1));
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
      expect(find.text('Tools'), findsNothing);

      // Flush AudioPlayerService debounce state-persist timer
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('SettingsScreen Appearance & Downloads Section Tests', () {
    testWidgets('Renders Theme toggle and settings sections', (tester) async {
      tester.view.physicalSize = const Size(1280, 2000);
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
      expect(find.text('Theme'), findsOneWidget);

      // Verify Download Folder & Downloads sections
      expect(find.text('DOWNLOAD FOLDER'), findsOneWidget);
      expect(find.text('DOWNLOADS'), findsOneWidget);

      // Verify App Updates section
      expect(find.text('APP UPDATES'), findsOneWidget);
      expect(find.text('Infyn DL v1.0.4'), findsAtLeastNWidgets(1));
      expect(find.text('Auto-Check for Updates'), findsOneWidget);

      // Verify Crafted by Vicky footer
      expect(find.text('Crafted by '), findsOneWidget);
      expect(find.text('Vicky'), findsOneWidget);
    });
  });

  group('AppReleaseInfo Version Comparison & JSON Parsing Tests', () {
    test('compareVersions correctly identifies newer and older versions', () {
      expect(AppReleaseInfo.compareVersions('1.0.4', '1.0.3'), greaterThan(0));
      expect(AppReleaseInfo.compareVersions('1.1.0', '1.0.3'), greaterThan(0));
      expect(AppReleaseInfo.compareVersions('2.0.0', '1.0.3'), greaterThan(0));
      expect(AppReleaseInfo.compareVersions('v1.0.4', '1.0.3'), greaterThan(0));
      expect(AppReleaseInfo.compareVersions('v1.0.3', '1.0.3'), equals(0));
      expect(AppReleaseInfo.compareVersions('1.0.2', '1.0.3'), lessThan(0));
      expect(AppReleaseInfo.compareVersions('1.0.3+4', '1.0.3'), equals(0));
    });

    test('fromJson parses release details and picks preferred APK', () {
      final sampleJson = {
        'tag_name': 'v1.0.4',
        'name': 'Infyn DL 1.0.4 Release',
        'body': 'Added new update checking mechanism and bug fixes.',
        'html_url': 'https://github.com/imvicky69/infyn-dl/releases/tag/v1.0.4',
        'published_at': '2026-09-11T20:00:00Z',
        'assets': [
          {
            'name': 'infyn-dl-arm64-v8a-release.apk',
            'browser_download_url':
                'https://github.com/imvicky69/infyn-dl/releases/download/v1.0.4/infyn-dl-arm64-v8a-release.apk',
          },
          {
            'name': 'infyn-dl-universal-release.apk',
            'browser_download_url':
                'https://github.com/imvicky69/infyn-dl/releases/download/v1.0.4/infyn-dl-universal-release.apk',
          }
        ]
      };

      final release = AppReleaseInfo.fromJson(
        sampleJson,
        currentVersion: '1.0.3',
      );

      expect(release.tagName, 'v1.0.4');
      expect(release.cleanVersion, '1.0.4');
      expect(release.title, 'Infyn DL 1.0.4 Release');
      expect(release.isUpdateAvailable, isTrue);
      expect(release.arm64ApkUrl, contains('arm64-v8a'));
      expect(release.universalApkUrl, contains('universal'));
      expect(release.preferredDownloadUrl, release.arm64ApkUrl);
    });
  });

  group('SettingsService Auto-Check Updates Setting Tests', () {
    test('Defaults to true, can be toggled and persisted', () async {
      final service = SettingsService.instance;
      await service.init();

      expect(service.autoCheckUpdates, isTrue);

      await service.setAutoCheckUpdates(false);
      expect(service.autoCheckUpdates, isFalse);

      await service.setAutoCheckUpdates(true);
      expect(service.autoCheckUpdates, isTrue);
    });
  });

  group('SettingsScreen Reactive Update Card Tests', () {
    testWidgets('Displays update banner when newer release is present',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final update = AppReleaseInfo(
        tagName: 'v1.1.0',
        title: 'Major Performance Update',
        body: 'Huge speed improvements and new feed design.',
        publishedAt: DateTime.now(),
        htmlUrl: 'https://github.com/imvicky69/infyn-dl/releases/tag/v1.1.0',
        arm64ApkUrl:
            'https://github.com/imvicky69/infyn-dl/releases/download/v1.1.0/app-arm64.apk',
        universalApkUrl: null,
        isUpdateAvailable: true,
      );

      AppUpdateService.instance.latestReleaseNotifier.value = update;

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            downloaderService: _MockDownloaderService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('NEW RELEASE'), findsOneWidget);
      expect(find.text('Major Performance Update'), findsOneWidget);
      expect(find.text('Download v1.1.0 (APK)'), findsOneWidget);

      // Clean up notifier
      AppUpdateService.instance.latestReleaseNotifier.value = null;
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
    bool isBatch = false,
    bool isLastBatchItem = true,
    String? batchPlaylistName,
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
