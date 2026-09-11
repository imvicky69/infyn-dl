import '../models/ytm_search_result.dart';
import '../../search/services/ytm_search_service.dart';

/// Legacy bridge for YouTube Music search, delegating directly to the
/// canonical [YtmSearchService] to avoid duplicated implementations.
class YtMusicSearchService {
  YtMusicSearchService._();
  static final YtMusicSearchService instance = YtMusicSearchService._();

  Future<List<YtmSearchResult>> searchSongs(String query) =>
      YtmSearchService.instance.searchYtmResults(query, category: 'songs');

  Future<List<YtmSearchResult>> searchPlaylists(String query) =>
      YtmSearchService.instance.searchYtmResults(query, category: 'playlists');

  Future<List<YtmSearchResult>> searchAlbums(String query) =>
      YtmSearchService.instance.searchYtmResults(query, category: 'albums');

  Future<List<YtmSearchResult>> searchVideos(String query) =>
      YtmSearchService.instance.searchYtmResults(query, category: 'videos');

  Future<List<YtmSearchResult>> searchAll(String query) =>
      YtmSearchService.instance.searchYtmResults(query, category: 'songs');
}
