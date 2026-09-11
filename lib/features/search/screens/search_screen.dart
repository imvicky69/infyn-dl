import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_feedback_helper.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../../downloader/services/download_history_service.dart';
import '../../downloader/services/music_download_manager.dart';
import '../../library/models/track.dart';
import '../../library/services/music_scanner_service.dart';
import '../../player/services/audio_player_service.dart';
import '../models/search_playlist_info.dart';
import '../services/ytm_search_service.dart';
import 'search_playlist_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum SearchFilter { songs, playlists }

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _songResults = [];
  List<SearchPlaylistInfo> _playlistResults = [];
  List<String> _recentSearches = [];
  bool _isLoading = false;
  SearchFilter _currentFilter = SearchFilter.songs;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    DownloadHistoryService.instance.changeNotifier
        .addListener(_onHistoryChanged);
    MusicScannerService.instance.tracksNotifier.addListener(_onHistoryChanged);
    MusicDownloadManager.instance.addListener(_onHistoryChanged);
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('recent_searches') ?? [];
      if (mounted) setState(() => _recentSearches = list);
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final updated = [
      clean,
      ..._recentSearches.where((s) => s.toLowerCase() != clean.toLowerCase())
    ].take(8).toList();
    if (mounted) setState(() => _recentSearches = updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_searches', updated);
    } catch (_) {}
  }

  Future<void> _clearRecentSearches() async {
    if (mounted) setState(() => _recentSearches = []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_searches');
    } catch (_) {}
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    DownloadHistoryService.instance.changeNotifier
        .removeListener(_onHistoryChanged);
    MusicScannerService.instance.tracksNotifier
        .removeListener(_onHistoryChanged);
    MusicDownloadManager.instance.removeListener(_onHistoryChanged);
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _songResults = [];
        _playlistResults = [];
        _isLoading = false;
      });
      return;
    }

    _saveRecentSearch(cleanQuery);

    setState(() {
      _isLoading = true;
    });

    if (_currentFilter == SearchFilter.songs) {
      final results = await YtmSearchService.instance.searchTracks(cleanQuery);
      if (mounted) {
        setState(() {
          _songResults = results;
          _isLoading = false;
        });
      }
    } else {
      final results =
          await YtmSearchService.instance.searchPlaylists(cleanQuery);
      if (mounted) {
        setState(() {
          _playlistResults = results;
          _isLoading = false;
        });
      }
    }
  }

  /// Checks if a search track is already downloaded locally
  Track? _findLocalTrack(Track track) {
    // 1. Check in scanned music tracks
    for (final local in MusicScannerService.instance.tracks) {
      if (local.filePath == null || local.filePath!.isEmpty) continue;
      if (local.webUrl != null &&
          track.webUrl != null &&
          local.webUrl!.trim() == track.webUrl!.trim()) {
        return local;
      }
      if (local.id == track.id ||
          local.title.trim().toLowerCase() ==
              track.title.trim().toLowerCase()) {
        if (File(local.filePath!).existsSync()) {
          return local;
        }
      }
    }
    return null;
  }

  /// Always download and play: if already downloaded, plays immediately.
  /// If not, downloads with UI feedback and auto-plays as soon as finished.
  Future<void> _handleSongTap(Track track) async {
    final localTrack = _findLocalTrack(track);
    if (localTrack != null && localTrack.isLocal) {
      // Already downloaded: play immediately
      AudioPlayerService.instance.playTrack(
        localTrack,
        queue: MusicScannerService.instance.tracks,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing "${localTrack.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // If already downloading, let the user know
    if (MusicDownloadManager.instance.isDownloading(track.id)) {
      final pct = MusicDownloadManager.instance.getPercentage(track.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading "${track.title}" ($pct)...'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    // Start download & play
    await _downloadAndPlayTrack(track);
  }

  Future<void> _downloadAndPlayTrack(Track track) async {
    HapticFeedback.lightImpact();
    UiFeedbackHelper.showSuccessToast(
      context,
      'Downloading "${track.title}" in background...',
    );
    await MusicDownloadManager.instance.downloadTrack(
      track,
      autoPlay: true,
    );
  }

  /// Downloads all tracks in a playlist in background
  Future<void> _downloadPlaylist(SearchPlaylistInfo playlist) async {
    final playlistId = playlist.id;
    if (MusicDownloadManager.instance.isBatchActive &&
        MusicDownloadManager.instance.batchPlaylistName == playlist.title) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playlist "${playlist.title}" is already downloading.'),
        ),
      );
      return;
    }

    try {
      UiFeedbackHelper.showSuccessToast(
        context,
        'Fetching tracks for "${playlist.title}"...',
      );

      final tracks =
          await YtmSearchService.instance.getPlaylistTracks(playlistId);
      if (tracks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tracks found in playlist.')),
          );
        }
        return;
      }

      if (!mounted) return;
      UiFeedbackHelper.showSuccessToast(
        context,
        'Downloading ${tracks.length} tracks from "${playlist.title}" in background...',
      );

      // Delegate batch download to background manager so navigating away never cancels it!
      MusicDownloadManager.instance.startBatchDownload(
        tracks: tracks,
        playlistName: playlist.title,
        playlistUrl: 'https://www.youtube.com/playlist?list=$playlistId',
        autoPlayFirst: true,
      );
    } catch (e) {
      if (mounted) {
        UiFeedbackHelper.showErrorToast(
          context,
          e.toString(),
          onRetry: () => _downloadPlaylist(playlist),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: false,
          onChanged: (val) {
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: 'Search YouTube Music...',
            hintStyle: TextStyle(color: AppColors.textMuted),
            border: InputBorder.none,
            prefixIcon:
                Icon(Icons.search_rounded, color: AppColors.textSecondary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17),
          onSubmitted: _performSearch,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Songs', SearchFilter.songs),
                const SizedBox(width: 8),
                _buildFilterChip('Playlists & Albums', SearchFilter.playlists),
              ],
            ),
          ),
          _buildActiveDownloadBanner(isDark),
          if (_searchController.text.isEmpty && _recentSearches.isNotEmpty)
            _buildRecentSearchesSection(),
          Expanded(
            child: _isLoading
                ? ShimmerLoading(
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        return _currentFilter == SearchFilter.songs
                            ? const TrackSkeletonTile()
                            : const PlaylistSkeletonCard();
                      },
                    ),
                  )
                : _isEmptyResults()
                    ? _buildEmptyStateView()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _currentFilter == SearchFilter.songs
                            ? _songResults.length
                            : _playlistResults.length,
                        itemBuilder: (context, index) {
                          if (_currentFilter == SearchFilter.songs) {
                            final track = _songResults[index];
                            return _buildSongTile(track);
                          } else {
                            final playlist = _playlistResults[index];
                            return _buildPlaylistTile(playlist);
                          }
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDownloadBanner(bool isDark) {
    return ListenableBuilder(
      listenable: MusicDownloadManager.instance,
      builder: (context, _) {
        final manager = MusicDownloadManager.instance;
        if (!manager.hasActiveDownloads) return const SizedBox.shrink();

        final isBatch = manager.isBatchActive;
        final activeList = manager.activeDownloads.values.toList();
        final firstActive = activeList.isNotEmpty ? activeList.first : null;

        final title = isBatch
            ? 'Downloading: ${manager.batchPlaylistName ?? "Playlist"} (${manager.batchCompleted}/${manager.batchTotal})'
            : 'Downloading: ${firstActive?.title ?? "Song"}';
        final pct = isBatch
            ? '${(manager.batchCurrentProgress * 100).toInt()}%'
            : firstActive?.percentage ?? '';
        final progress = isBatch
            ? manager.batchCurrentProgress
            : firstActive?.progress ?? 0.0;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_download_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (pct.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      pct,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 3,
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentSearchesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'RECENT SEARCHES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearRecentSearches,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((query) {
              return ActionChip(
                avatar: Icon(
                  Icons.north_west_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                label: Text(
                  query,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: AppColors.surfaceElevated,
                side: BorderSide(color: AppColors.surfaceBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onPressed: () {
                  _searchController.text = query;
                  _performSearch(query);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateView() {
    if (_searchController.text.trim().isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 56,
                color: AppColors.surfaceBorder,
              ),
              const SizedBox(height: 16),
              Text(
                'No results found for "${_searchController.text.trim()}"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Check your spelling or try searching for another song, artist, or playlist.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_recentSearches.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AppColors.logoFor(context),
              width: 64,
              height: 64,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.search_rounded,
                size: 56,
                color: AppColors.surfaceBorder,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Search & Download Music',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search for songs, playlists, or albums to download & play',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isEmptyResults() {
    return _currentFilter == SearchFilter.songs
        ? _songResults.isEmpty
        : _playlistResults.isEmpty;
  }

  Widget _buildFilterChip(String label, SearchFilter filter) {
    final isSelected = _currentFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (selected) {
        if (selected && _currentFilter != filter) {
          setState(() => _currentFilter = filter);
          if (_searchController.text.isNotEmpty) {
            _performSearch(_searchController.text);
          }
        }
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
        ),
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _buildSongTile(Track track) {
    final localTrack = _findLocalTrack(track);
    final isDownloaded = localTrack != null && localTrack.isLocal;
    final isDownloading = MusicDownloadManager.instance.isDownloading(track.id);
    final progress = MusicDownloadManager.instance.getProgress(track.id);
    final percentage = MusicDownloadManager.instance.getPercentage(track.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: track.hasArtwork
            ? Image.network(
                track.artworkPath!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackArt(),
              )
            : _buildFallbackArt(),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          if (isDownloading) ...[
            const SizedBox(width: 8),
            Text(
              percentage.isNotEmpty ? percentage : 'Downloading...',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (isDownloaded) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Downloaded',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            track.formattedDuration,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(width: 8),
          if (isDownloading)
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress > 0.0 ? progress : null,
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                  Icon(
                    Icons.downloading_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            )
          else if (isDownloaded)
            IconButton(
              icon: Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              tooltip: 'Play downloaded song',
              onPressed: () => _handleSongTap(track),
            )
          else
            IconButton(
              icon: Icon(
                Icons.download_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              tooltip: 'Download & Play',
              onPressed: () => _downloadAndPlayTrack(track),
            ),
        ],
      ),
      onTap: () => _handleSongTap(track),
    );
  }

  void _openPlaylistDetail(SearchPlaylistInfo playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchPlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  Widget _buildPlaylistTile(SearchPlaylistInfo playlist) {
    final isDownloading = MusicDownloadManager.instance.isBatchActive &&
        MusicDownloadManager.instance.batchPlaylistName == playlist.title;
    final progressStatus = isDownloading
        ? '${MusicDownloadManager.instance.batchCompleted}/${MusicDownloadManager.instance.batchTotal} tracks (${(MusicDownloadManager.instance.batchCurrentProgress * 100).toInt()}%)'
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: playlist.thumbnailUrl != null
            ? Image.network(
                playlist.thumbnailUrl!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackArt(),
              )
            : _buildFallbackArt(),
      ),
      title: Text(
        playlist.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        isDownloading && progressStatus != null
            ? progressStatus
            : playlist.subtitle,
        style: TextStyle(
          color: isDownloading ? AppColors.primary : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: isDownloading ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isDownloading
          ? SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.download_for_offline_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  tooltip: 'Quick Download All',
                  onPressed: () => _downloadPlaylist(playlist),
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  tooltip: 'View Tracks & Select',
                  onPressed: () => _openPlaylistDetail(playlist),
                ),
              ],
            ),
      onTap: () => _openPlaylistDetail(playlist),
    );
  }

  Widget _buildFallbackArt() {
    return Container(
      width: 50,
      height: 50,
      color: AppColors.surfaceElevated,
      child: Icon(
        Icons.music_note_rounded,
        color: AppColors.textSecondary,
        size: 24,
      ),
    );
  }
}
