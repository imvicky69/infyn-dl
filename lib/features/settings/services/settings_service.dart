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

  /// Resolves the effective download directory.
  /// Uses customDownloadPath if configured and valid, otherwise uses standard Downloads/infyn-dl.
  Future<String> resolveDownloadDirectory() async {
    final custom = customDownloadPath;
    if (custom != null && custom.isNotEmpty) {
      try {
        final dir = Directory(custom);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return custom;
      } catch (e) {
        debugPrint('Custom directory invalid, falling back to default: $e');
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android public Downloads folder
      const androidPath = '/storage/emulated/0/Download/infyn-dl';
      return androidPath;
    }

    // Default fallback
    final appDocs = await getApplicationDocumentsDirectory();
    final fallback = p.join(appDocs.path, 'infyn-dl');
    await Directory(fallback).create(recursive: true);
    return fallback;
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
