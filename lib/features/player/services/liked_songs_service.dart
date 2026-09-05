import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the set of liked track IDs.
/// For local files, this is usually the file path. For remote files, the YouTube video ID.
class LikedSongsService extends ChangeNotifier {
  LikedSongsService._();
  static final LikedSongsService instance = LikedSongsService._();

  static const String _kLikedKey = 'liked_track_paths';

  final Set<String> _likedIds = {};

  Set<String> get likedIds => Set.unmodifiable(_likedIds);

  bool isLiked(String trackId) => _likedIds.contains(trackId);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_kLikedKey) ?? [];
    _likedIds
      ..clear()
      ..addAll(stored);
    notifyListeners();
  }

  Future<void> toggleLike(String trackId) async {
    if (_likedIds.contains(trackId)) {
      _likedIds.remove(trackId);
    } else {
      _likedIds.add(trackId);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kLikedKey, _likedIds.toList());
  }
}
