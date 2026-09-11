import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

/// Service managing completely local user music preferences.
///
/// Stores language, genre, and mood preferences in SharedPreferences with
/// zero tracking, zero external telemetry, and 100% on-device privacy.
class UserPreferencesService {
  static const String _prefKey = 'local_user_music_preferences';

  static UserPreferencesService? _instance;
  static UserPreferencesService get instance =>
      _instance ??= UserPreferencesService._();

  UserPreferencesService._();

  final ValueNotifier<UserPreferences> preferencesNotifier =
      ValueNotifier<UserPreferences>(const UserPreferences());

  UserPreferences get preferences => preferencesNotifier.value;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_prefKey);
      if (rawJson != null && rawJson.trim().isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(rawJson);
        preferencesNotifier.value = UserPreferences.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('UserPreferencesService: Error loading preferences: $e');
    }
  }

  Future<void> updatePreferences(UserPreferences newPrefs) async {
    preferencesNotifier.value = newPrefs;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(newPrefs.toJson());
      await prefs.setString(_prefKey, jsonStr);
    } catch (e) {
      debugPrint('UserPreferencesService: Error saving preferences: $e');
    }
  }

  Future<void> setLanguages(List<String> languages) async {
    await updatePreferences(preferences.copyWith(
      languages: languages,
      isOnboarded: true,
    ));
  }

  Future<void> setGenres(List<String> genres) async {
    await updatePreferences(preferences.copyWith(
      genres: genres,
      isOnboarded: true,
    ));
  }

  Future<void> setMoods(List<String> moods) async {
    await updatePreferences(preferences.copyWith(
      moods: moods,
      isOnboarded: true,
    ));
  }

  Future<void> completeOnboarding() async {
    if (!preferences.isOnboarded) {
      await updatePreferences(preferences.copyWith(isOnboarded: true));
    }
  }

  Future<void> resetPreferences() async {
    preferencesNotifier.value = const UserPreferences();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
