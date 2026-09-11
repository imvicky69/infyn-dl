import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/catalog_playlist.dart';

/// Service responsible for fetching, validating, and caching the remote playlist catalog.
///
/// Ensures 100% offline functionality by falling back to locally cached JSON
/// and pre-bundled asset playlists, with non-blocking background refreshes.
class CatalogService {
  static const String _defaultCatalogUrl =
      'https://raw.githubusercontent.com/imvicky69/infyn-dl/main/catalog/playlists.json';
  static const String _bundledAssetPath = 'catalog/playlists.json';
  static const String _cachePrefKey = 'cached_playlist_catalog_json';
  static const String _lastFetchPrefKey = 'catalog_last_fetch_timestamp';
  static const Duration _refreshThrottle = Duration(hours: 6);

  static CatalogService? _instance;
  static CatalogService get instance => _instance ??= CatalogService._();

  CatalogService._();

  final ValueNotifier<List<CatalogPlaylist>> playlistsNotifier =
      ValueNotifier<List<CatalogPlaylist>>([]);
  final ValueNotifier<bool> isRefreshingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastErrorNotifier = ValueNotifier<String?>(null);

  List<CatalogPlaylist> get playlists => playlistsNotifier.value;
  bool _isInitialized = false;

  /// Initializes the catalog synchronously from cache or bundled asset,
  /// then triggers a non-blocking background refresh if needed.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Fast path: Load from local cache or bundled asset immediately
    await _loadFromLocalCacheOrAsset();

    // 2. Slow path: Background refresh if cache is expired or missing
    unawaited(refreshRemote(force: false));
  }

  /// Loads catalog from SharedPreferences cache, falling back to bundled asset JSON.
  Future<void> _loadFromLocalCacheOrAsset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJsonStr = prefs.getString(_cachePrefKey);

      // Read pre-bundled asset
      final assetStr = await rootBundle.loadString(_bundledAssetPath);
      final assetParsed = _parseAndValidate(assetStr);
      final assetVersion = _extractVersion(assetStr);

      if (cachedJsonStr != null && cachedJsonStr.trim().isNotEmpty) {
        final cachedVersion = _extractVersion(cachedJsonStr);
        if (cachedVersion >= assetVersion) {
          final parsed = _parseAndValidate(cachedJsonStr);
          if (parsed.isNotEmpty) {
            playlistsNotifier.value = parsed;
            return;
          }
        } else {
          // Invalidate outdated cache
          await prefs.remove(_cachePrefKey);
          await prefs.remove(_lastFetchPrefKey);
        }
      }

      if (assetParsed.isNotEmpty) {
        playlistsNotifier.value = assetParsed;
      }
    } catch (e) {
      debugPrint('CatalogService: Error loading local catalog: $e');
    }
  }

  int _extractVersion(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map && decoded['version'] is num) {
        return (decoded['version'] as num).toInt();
      }
    } catch (_) {}
    return 1;
  }

  /// Refreshes the catalog from the remote GitHub endpoint in the background.
  /// Does NOT throw errors to UI; caches valid responses only.
  Future<bool> refreshRemote({bool force = false}) async {
    if (isRefreshingNotifier.value) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchMillis = prefs.getInt(_lastFetchPrefKey) ?? 0;
      final timeSinceLast =
          DateTime.now().millisecondsSinceEpoch - lastFetchMillis;

      if (!force &&
          timeSinceLast < _refreshThrottle.inMilliseconds &&
          playlists.isNotEmpty) {
        return false;
      }

      isRefreshingNotifier.value = true;
      lastErrorNotifier.value = null;

      final url = Uri.parse(_defaultCatalogUrl);
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final newPlaylists = _parseAndValidate(response.body);
        if (newPlaylists.isNotEmpty) {
          playlistsNotifier.value = newPlaylists;
          await prefs.setString(_cachePrefKey, response.body);
          await prefs.setInt(
              _lastFetchPrefKey, DateTime.now().millisecondsSinceEpoch);
          return true;
        } else {
          lastErrorNotifier.value = 'Remote catalog was empty or invalid';
        }
      } else {
        lastErrorNotifier.value = 'HTTP ${response.statusCode} from GitHub';
      }
    } catch (e) {
      debugPrint(
          'CatalogService: Remote refresh failed (using cached catalog): $e');
      lastErrorNotifier.value = e.toString();
    } finally {
      isRefreshingNotifier.value = false;
    }

    return false;
  }

  /// Tolerant parser that validates each playlist entry.
  /// Discards malformed items without crashing or dropping valid entries.
  List<CatalogPlaylist> _parseAndValidate(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      final List<dynamic> rawList;

      if (decoded is Map<String, dynamic> && decoded['playlists'] is List) {
        rawList = decoded['playlists'] as List<dynamic>;
      } else if (decoded is List) {
        rawList = decoded;
      } else {
        return const [];
      }

      final validPlaylists = <CatalogPlaylist>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final playlist = CatalogPlaylist.fromJson(item);
          if (playlist != null) {
            validPlaylists.add(playlist);
          }
        }
      }

      return validPlaylists;
    } catch (e) {
      debugPrint('CatalogService: Failed to parse catalog JSON: $e');
      return const [];
    }
  }

  /// Clears cache and reloads seed asset (useful for debugging or reset).
  Future<void> resetToBundled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachePrefKey);
    await prefs.remove(_lastFetchPrefKey);
    await _loadFromLocalCacheOrAsset();
  }
}
