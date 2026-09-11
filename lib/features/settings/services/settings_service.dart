import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../downloader/models/download_format.dart';

/// Centralized configuration and user preferences service.
class SettingsService {
  static const String _keyDownloadPath = 'custom_download_path';
  static const String _keyAutoSkipDuplicates = 'auto_skip_duplicates';
  static const String _keyPlaylistSubfolder = 'playlist_subfolder';
  static const String _keyConcurrentDownloads = 'concurrent_downloads';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAutoCheckUpdates = 'auto_check_updates';

  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();

  SettingsService._();

  SharedPreferences? _prefs;
  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final savedTheme = _prefs?.getString(_keyThemeMode);
    if (savedTheme == 'light') {
      themeModeNotifier.value = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      themeModeNotifier.value = ThemeMode.dark;
    } else {
      themeModeNotifier.value = ThemeMode.system;
    }
  }

  /// Current global theme mode (system, light, or dark).
  ThemeMode get themeMode => themeModeNotifier.value;

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final str = mode == ThemeMode.dark
        ? 'dark'
        : (mode == ThemeMode.light ? 'light' : 'system');
    await _prefs?.setString(_keyThemeMode, str);
  }

  /// The custom download directory chosen by the user, if set.
  String? get customDownloadPath => _prefs?.getString(_keyDownloadPath);

  Future<void> setCustomDownloadPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs?.remove(_keyDownloadPath);
    } else {
      await _prefs?.setString(_keyDownloadPath, path);
    }
  }

  /// Whether to automatically skip files that already exist in the target folder.
  bool get autoSkipDuplicates =>
      _prefs?.getBool(_keyAutoSkipDuplicates) ?? true;

  Future<void> setAutoSkipDuplicates(bool value) async {
    await _prefs?.setBool(_keyAutoSkipDuplicates, value);
  }

  /// Whether to group playlist downloads into a dedicated subfolder named after the playlist.
  bool get playlistSubfolder => _prefs?.getBool(_keyPlaylistSubfolder) ?? true;

  Future<void> setPlaylistSubfolder(bool value) async {
    await _prefs?.setBool(_keyPlaylistSubfolder, value);
  }

  /// Number of simultaneous parallel downloads for playlists (1 to 5, default: 3).
  int get concurrentDownloads => _prefs?.getInt(_keyConcurrentDownloads) ?? 3;

  Future<void> setConcurrentDownloads(int count) async {
    await _prefs?.setInt(_keyConcurrentDownloads, count.clamp(1, 5));
  }

  /// Whether the app automatically checks GitHub for new releases on launch.
  bool get autoCheckUpdates => _prefs?.getBool(_keyAutoCheckUpdates) ?? true;

  Future<void> setAutoCheckUpdates(bool value) async {
    await _prefs?.setBool(_keyAutoCheckUpdates, value);
  }

  /// Resolves the effective download directory.
  /// Uses customDownloadPath if configured and valid, otherwise uses standard Downloads/infyn-dl.
  Future<String> resolveDownloadDirectory() async {
    final custom = customDownloadPath;
    if (custom != null && custom.isNotEmpty) {
      try {
        final dir = Directory(custom);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return custom;
      } catch (e) {
        debugPrint('Custom directory invalid, falling back to default: $e');
      }
    }

    try {
      Directory? baseDir;
      if (!kIsWeb && Platform.isAndroid) {
        try {
          baseDir = await getExternalStorageDirectory();
        } catch (_) {}
      } else if (!kIsWeb && Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          final winDir = p.join(userProfile, 'Downloads', 'infyn-dl', 'Music');
          final dir = Directory(winDir);
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          return winDir;
        }
      }

      try {
        baseDir ??= await getApplicationDocumentsDirectory();
      } catch (_) {}

      final defaultPath = baseDir != null
          ? p.join(baseDir.path, 'Music')
          : p.join(Directory.systemTemp.path, 'infyn-dl', 'Music');
      final dir = Directory(defaultPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return defaultPath;
    } catch (e) {
      debugPrint('Error resolving download directory: $e');
      final fallback = p.join(Directory.systemTemp.path, 'infyn-dl', 'Music');
      try {
        final dir = Directory(fallback);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
      } catch (_) {}
      return fallback;
    }
  }

  /// Resolves the effective download directory for a specific format and optional playlist.
  /// Video files (mp4) are stored in a dedicated 'Videos' subdirectory.
  Future<String> resolveDownloadDirectoryForFormat({
    required DownloadFormat format,
    String? playlistName,
  }) async {
    final baseDir = await resolveDownloadDirectory();
    final isVideo = format == DownloadFormat.mp4;
    final parentDir = isVideo ? p.join(baseDir, 'Videos') : baseDir;

    if (playlistName != null &&
        playlistName.trim().isNotEmpty &&
        playlistSubfolder) {
      final sanitized =
          playlistName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
      return p.join(parentDir, sanitized);
    }

    return parentDir;
  }
}
