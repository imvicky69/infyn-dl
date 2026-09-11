import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../library/models/track.dart';

/// Service managing persistent recently played music history.
///
/// Records tracks when played, saves up to 30 tracks in local SharedPreferences,
/// and provides reactive ValueNotifier for the UI feed.
class RecentlyPlayedService {
  static const String _prefKey = 'recently_played_tracks_v1';
  static const int _maxHistory = 30;

  static RecentlyPlayedService? _instance;
  static RecentlyPlayedService get instance =>
      _instance ??= RecentlyPlayedService._();

  RecentlyPlayedService._();

  final ValueNotifier<List<Track>> recentlyPlayedNotifier =
      ValueNotifier<List<Track>>([]);

  List<Track> get recentlyPlayed => recentlyPlayedNotifier.value;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        final tracks = decoded
            .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
            .where((t) => t.id.isNotEmpty && t.title.isNotEmpty)
            .toList();
        recentlyPlayedNotifier.value = tracks;
      }
    } catch (e) {
      debugPrint('RecentlyPlayedService: Error loading history: $e');
    }
  }

  Future<void> addTrack(Track track) async {
    if (track.title.isEmpty) return;

    // Remove duplicates by ID or identical title & artist
    final updated = List<Track>.from(recentlyPlayedNotifier.value);
    updated.removeWhere((t) =>
        t.id == track.id ||
        (t.title.trim().toLowerCase() == track.title.trim().toLowerCase() &&
            t.artist.trim().toLowerCase() ==
                track.artist.trim().toLowerCase()));

    // Insert at front
    updated.insert(0, track);

    // Trim to max items
    if (updated.length > _maxHistory) {
      updated.removeRange(_maxHistory, updated.length);
    }

    recentlyPlayedNotifier.value = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = updated.map((t) => t.toJson()).toList();
      await prefs.setString(_prefKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('RecentlyPlayedService: Error persisting track: $e');
    }
  }

  Future<void> clearHistory() async {
    recentlyPlayedNotifier.value = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (e) {
      debugPrint('RecentlyPlayedService: Error clearing history: $e');
    }
  }
}
