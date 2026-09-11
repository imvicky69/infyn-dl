import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_release_info.dart';

/// Current installed version of the Infyn DL application.
const String kCurrentAppVersion = '1.0.3';

/// Service responsible for querying GitHub Releases API to detect new versions
/// and prompt the user with download/release notes.
class AppUpdateService {
  static const String _githubLatestUrl =
      'https://api.github.com/repos/imvicky69/infyn-dl/releases/latest';
  static const String _lastCheckKey = 'last_update_check_epoch';

  static AppUpdateService? _instance;
  static AppUpdateService get instance => _instance ??= AppUpdateService._();

  AppUpdateService._();

  final ValueNotifier<AppReleaseInfo?> latestReleaseNotifier =
      ValueNotifier<AppReleaseInfo?>(null);
  final ValueNotifier<bool> isCheckingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastErrorNotifier = ValueNotifier<String?>(null);

  AppReleaseInfo? get latestRelease => latestReleaseNotifier.value;
  bool get hasUpdate => latestReleaseNotifier.value?.isUpdateAvailable ?? false;

  /// Checks GitHub releases API for new versions.
  Future<AppReleaseInfo?> checkForUpdates({bool force = false}) async {
    if (isCheckingNotifier.value) return latestRelease;

    isCheckingNotifier.value = true;
    lastErrorNotifier.value = null;

    try {
      final client = http.Client();
      final response = await client
          .get(
            Uri.parse(_githubLatestUrl),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Infyn-DL-App',
            },
          )
          .timeout(const Duration(seconds: 10));

      client.close();

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final release = AppReleaseInfo.fromJson(
          data,
          currentVersion: kCurrentAppVersion,
        );
        latestReleaseNotifier.value = release;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

        return release;
      } else if (response.statusCode == 404) {
        // No releases published yet
        lastErrorNotifier.value = 'No public releases found.';
      } else {
        lastErrorNotifier.value =
            'Server returned error code ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('AppUpdateService error checking updates: $e');
      lastErrorNotifier.value = 'Could not check for updates. Check internet.';
    } finally {
      isCheckingNotifier.value = false;
    }

    return latestRelease;
  }

  /// Opens the direct APK download URL or GitHub release page in the system browser.
  Future<bool> launchDownloadPage([AppReleaseInfo? release]) async {
    final info = release ?? latestRelease;
    final urlStr = info?.preferredDownloadUrl ??
        'https://github.com/imvicky69/infyn-dl/releases/latest';

    final uri = Uri.parse(urlStr);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching update URL: $e');
      return false;
    }
  }
}
