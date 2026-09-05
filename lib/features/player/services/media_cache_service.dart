import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches extracted direct media stream URLs to prevent repeatedly calling yt-dlp.
class MediaCacheService {
  MediaCacheService._();
  static final MediaCacheService instance = MediaCacheService._();

  static const String _kCacheKey = 'stream_url_cache';
  
  // 2 hours TTL for YouTube stream URLs
  static const Duration _kTtl = Duration(hours: 2);

  Map<String, _CacheEntry> _cache = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kCacheKey);
    if (stored != null) {
      try {
        final decoded = jsonDecode(stored) as Map<String, dynamic>;
        _cache = decoded.map((k, v) => MapEntry(k, _CacheEntry.fromJson(v)));
      } catch (e) {
        // Corrupted cache, ignore
      }
    }
    _purgeExpired();
  }

  String? getStreamUrl(String webUrl) {
    _purgeExpired();
    return _cache[webUrl]?.streamUrl;
  }

  Future<void> setStreamUrl(String webUrl, String streamUrl) async {
    _cache[webUrl] = _CacheEntry(
      streamUrl: streamUrl,
      expiresAt: DateTime.now().add(_kTtl),
    );
    await _persist();
  }

  void _purgeExpired() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) => entry.expiresAt.isBefore(now));
  }

  Future<void> _persist() async {
    _purgeExpired();
    final prefs = await SharedPreferences.getInstance();
    final encoded = _cache.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_kCacheKey, jsonEncode(encoded));
  }
}

class _CacheEntry {
  final String streamUrl;
  final DateTime expiresAt;

  _CacheEntry({required this.streamUrl, required this.expiresAt});

  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    return _CacheEntry(
      streamUrl: json['streamUrl'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'streamUrl': streamUrl,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}
