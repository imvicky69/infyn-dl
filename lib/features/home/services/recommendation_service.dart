import '../models/catalog_playlist.dart';
import '../models/user_preferences.dart';
import 'catalog_service.dart';
import 'user_preferences_service.dart';
import '../../downloader/services/download_history_service.dart';

/// Local recommendation ranking and personalization engine.
///
/// Operates 100% on-device with zero machine learning and zero cloud tracking.
/// Uses transparent heuristics (language, genre, mood matching, diversity jitter)
/// to rank catalog playlists into tailored feed sections.
class RecommendationService {
  static RecommendationService? _instance;
  static RecommendationService get instance =>
      _instance ??= RecommendationService._();

  RecommendationService._();

  final CatalogService _catalogService = CatalogService.instance;
  final UserPreferencesService _prefService = UserPreferencesService.instance;

  /// Calculates a personalized recommendation score for a given playlist.
  int computeScore({
    required CatalogPlaylist playlist,
    required UserPreferences preferences,
    required Set<String> downloadedPlaylistNames,
    int? diversitySeed,
  }) {
    int score = 0;

    // 1. Language matching (strongest affinity)
    for (final lang in playlist.languages) {
      if (preferences.languages
          .any((l) => l.toLowerCase() == lang.toLowerCase())) {
        score += 30;
      }
    }

    // 2. Genre matching (strong affinity)
    for (final genre in playlist.genres) {
      if (preferences.genres
          .any((g) => g.toLowerCase() == genre.toLowerCase())) {
        score += 25;
      }
    }

    // 3. Mood matching (moderate affinity)
    for (final mood in playlist.moods) {
      if (preferences.moods.any((m) => m.toLowerCase() == mood.toLowerCase())) {
        score += 15;
      }
    }

    // 4. Tag matching (small boost)
    for (final tag in playlist.tags) {
      final tagLower = tag.toLowerCase();
      if (preferences.genres.any((g) => g.toLowerCase() == tagLower) ||
          preferences.moods.any((m) => m.toLowerCase() == tagLower)) {
        score += 5;
      }
    }

    // 5. Featured curator boost
    if (playlist.featured) {
      score += 10;
    }

    // 6. Deprioritize already fully downloaded playlists in "For You"
    final cleanTitle = playlist.title.trim().toLowerCase();
    if (downloadedPlaylistNames.contains(cleanTitle)) {
      score -= 25;
    }

    // 7. Small deterministic diversity jitter to keep recommendations fresh
    final seed = diversitySeed ?? (DateTime.now().day * 31);
    final jitter = (playlist.id.hashCode.abs() + seed) % 6;
    score += jitter;

    return score;
  }

  /// Returns playlists for the "For You" section, sorted by recommendation score descending.
  Future<List<CatalogPlaylist>> getForYouPlaylists({int limit = 10}) async {
    final catalog = _catalogService.playlists;
    if (catalog.isEmpty) return const [];

    final prefs = _prefService.preferences;
    final downloadedNames = await _getDownloadedPlaylistNames();

    final scored = catalog.map((playlist) {
      final score = computeScore(
        playlist: playlist,
        preferences: prefs,
        downloadedPlaylistNames: downloadedNames,
      );
      return MapEntry(playlist, score);
    }).toList();

    // Sort descending by score
    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.map((e) => e.key).take(limit).toList();
  }

  /// Returns featured playlists highlighted in the catalog.
  List<CatalogPlaylist> getFeaturedPlaylists() {
    final catalog = _catalogService.playlists;
    final featured = catalog.where((p) => p.featured).toList();
    if (featured.isNotEmpty) return featured;
    return catalog.take(5).toList();
  }

  /// Returns diverse recommended playlists that complement the user's feed.
  Future<List<CatalogPlaylist>> getRecommendedPlaylists({
    int limit = 10,
    List<String>? excludeIds,
  }) async {
    final catalog = _catalogService.playlists;
    final excluded = (excludeIds ?? const []).toSet();
    final candidates = catalog.where((p) => !excluded.contains(p.id)).toList();

    // Deterministic shuffle using current day of year for fresh daily rotation
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    candidates.sort((a, b) {
      final hashA = (a.id.hashCode.abs() + dayOfYear) % 100;
      final hashB = (b.id.hashCode.abs() + dayOfYear) % 100;
      return hashB.compareTo(hashA);
    });

    return candidates.take(limit).toList();
  }

  /// Filters playlists by a specific genre (case-insensitive).
  List<CatalogPlaylist> filterByGenre(String genre) {
    final catalog = _catalogService.playlists;
    if (genre.isEmpty || genre.toLowerCase() == 'all') return catalog;
    final gLower = genre.toLowerCase();
    return catalog.where((p) {
      return p.genres.any((g) => g.toLowerCase() == gLower) ||
          p.tags.any((t) => t.toLowerCase() == gLower);
    }).toList();
  }

  /// Filters playlists by a specific language (case-insensitive).
  List<CatalogPlaylist> filterByLanguage(String language) {
    final catalog = _catalogService.playlists;
    if (language.isEmpty || language.toLowerCase() == 'all') return catalog;
    final lLower = language.toLowerCase();
    return catalog.where((p) {
      return p.languages.any((l) => l.toLowerCase() == lLower);
    }).toList();
  }

  /// Aggregates all unique genres available in the current catalog.
  List<String> getAvailableGenres() {
    final catalog = _catalogService.playlists;
    final genres = <String>{};
    for (final p in catalog) {
      genres.addAll(p.genres);
    }
    return genres.toList()..sort();
  }

  /// Aggregates all unique languages available in the current catalog.
  List<String> getAvailableLanguages() {
    final catalog = _catalogService.playlists;
    final languages = <String>{};
    for (final p in catalog) {
      languages.addAll(p.languages);
    }
    return languages.toList()..sort();
  }

  Future<Set<String>> _getDownloadedPlaylistNames() async {
    try {
      final history =
          await DownloadHistoryService.instance.getExistingHistory();
      final names = <String>{};
      for (final item in history) {
        if (item.playlistName != null && item.playlistName!.trim().isNotEmpty) {
          names.add(item.playlistName!.trim().toLowerCase());
        }
      }
      return names;
    } catch (_) {
      return const {};
    }
  }
}
