import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_feedback_helper.dart';
import '../../downloader/services/download_history_service.dart';
import '../../downloader/services/music_download_manager.dart';
import '../../player/services/audio_player_service.dart';
import '../../player/services/liked_songs_service.dart';
import '../../player/widgets/mini_player.dart';
import '../../search/services/ytm_search_service.dart';
import '../models/music_playlist.dart';
import '../models/track.dart';
import '../services/music_scanner_service.dart';

/// YouTube Music style playlist detail screen.
/// Displays downloaded tracks, and allows users to fetch all songs from the online
/// playlist on YouTube Music and download more tracks directly into the same folder.
class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    this.onBack,
  });

  final MusicPlaylist playlist;
  final VoidCallback? onBack;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Online playlist fetch state
  List<Track>? _onlineTracks;
  bool _isFetchingOnline = false;
  String? _onlineError;
  String? _onlinePlaylistId;
  String? _onlinePlaylistUrl;

  @override
  void initState() {
    super.initState();
    _checkAndLoadCachedOnlinePlaylist();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Attempts to find a cached online playlist ID from download history
  Future<void> _checkAndLoadCachedOnlinePlaylist() async {
    if (widget.playlist.name == 'Liked Songs') return;

    try {
      final history = await DownloadHistoryService.instance.getHistory();
      final matching = history.where((h) =>
          (h.playlistName != null &&
              h.playlistName!.trim().toLowerCase() ==
                  widget.playlist.name.trim().toLowerCase()) ||
          widget.playlist.tracks
              .any((t) => t.filePath != null && t.filePath == h.filePath));

      for (final item in matching) {
        if (item.playlistUrl != null && item.playlistUrl!.isNotEmpty) {
          final id = _extractPlaylistId(item.playlistUrl!);
          if (id != null && id.isNotEmpty) {
            _onlinePlaylistId = id;
            _onlinePlaylistUrl = item.playlistUrl;
            final cached =
                YtmSearchService.instance.getCachedPlaylistTracksSync(id);
            if (cached != null && cached.isNotEmpty && mounted) {
              setState(() {
                _onlineTracks = cached;
              });
            }
            break;
          }
        }
      }
    } catch (_) {}
  }

  /// Resolves the exact local folder on disk where this playlist's files are downloaded
  String? get _downloadedFolderPath {
    for (final t in widget.playlist.tracks) {
      if (t.filePath != null && t.filePath!.trim().isNotEmpty) {
        return p.dirname(t.filePath!);
      }
    }
    final current = MusicScannerService.instance.playlists.firstWhere(
      (p) =>
          p.name.trim().toLowerCase() ==
          widget.playlist.name.trim().toLowerCase(),
      orElse: () => widget.playlist,
    );
    for (final t in current.tracks) {
      if (t.filePath != null && t.filePath!.trim().isNotEmpty) {
        return p.dirname(t.filePath!);
      }
    }
    return null;
  }

  static String? _extractPlaylistId(String url) {
    if (url.contains('list=')) {
      final match = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)').firstMatch(url);
      if (match != null && match.groupCount >= 1) return match.group(1);
    }
    if (url.startsWith('VL') || url.startsWith('PL') || url.startsWith('RD')) {
      return url;
    }
    return null;
  }

  /// Fetches all tracks of this playlist from YouTube Music
  Future<void> _fetchOnlinePlaylist({bool force = false}) async {
    if (_isFetchingOnline) return;
    setState(() {
      _isFetchingOnline = true;
      _onlineError = null;
    });

    try {
      String? playlistId = _onlinePlaylistId;
      String? playlistUrl = _onlinePlaylistUrl;

      // 1. Try to find playlist URL from DownloadHistoryService
      if (playlistId == null || playlistId.isEmpty) {
        final history = await DownloadHistoryService.instance.getHistory();
        final matching = history.where((h) =>
            (h.playlistName != null &&
                h.playlistName!.trim().toLowerCase() ==
                    widget.playlist.name.trim().toLowerCase()) ||
            widget.playlist.tracks
                .any((t) => t.filePath != null && t.filePath == h.filePath));

        for (final item in matching) {
          if (item.playlistUrl != null && item.playlistUrl!.isNotEmpty) {
            final extracted = _extractPlaylistId(item.playlistUrl!);
            if (extracted != null && extracted.isNotEmpty) {
              playlistId = extracted;
              playlistUrl = item.playlistUrl;
              break;
            }
          }
        }
      }

      // 2. Fallback: Search YouTube Music for playlist by title
      if (playlistId == null || playlistId.isEmpty) {
        final results = await YtmSearchService.instance
            .searchPlaylists(widget.playlist.name);
        if (results.isNotEmpty) {
          final best = results.firstWhere(
            (r) =>
                r.title.trim().toLowerCase() ==
                widget.playlist.name.trim().toLowerCase(),
            orElse: () => results.first,
          );
          playlistId = best.id;
          playlistUrl = 'https://www.youtube.com/playlist?list=$playlistId';
        }
      }

      if (playlistId == null || playlistId.isEmpty) {
        if (mounted) {
          setState(() {
            _isFetchingOnline = false;
            _onlineError =
                'Could not locate matching playlist on YouTube Music.';
          });
        }
        return;
      }

      _onlinePlaylistId = playlistId;
      _onlinePlaylistUrl =
          playlistUrl ?? 'https://www.youtube.com/playlist?list=$playlistId';

      final tracks = await YtmSearchService.instance
          .getPlaylistTracks(playlistId, forceRefresh: force);

      if (mounted) {
        setState(() {
          _onlineTracks = tracks;
          _isFetchingOnline = false;
          if (tracks.isEmpty) {
            _onlineError = 'No tracks found in online playlist.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingOnline = false;
          _onlineError = 'Failed to fetch online songs: $e';
        });
      }
    }
  }

  static String _cleanForComparison(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  bool _isDownloadedLocally(Track onlineTrack, List<Track> localTracks) {
    for (final local in localTracks) {
      if (local.webUrl != null &&
          onlineTrack.webUrl != null &&
          local.webUrl!.trim() == onlineTrack.webUrl!.trim()) {
        return true;
      }
      if (local.id == onlineTrack.id ||
          (local.webUrl != null && local.webUrl!.contains(onlineTrack.id))) {
        return true;
      }
      final lTitle = _cleanForComparison(local.title);
      final oTitle = _cleanForComparison(onlineTrack.title);
      if (lTitle.isNotEmpty && lTitle == oTitle) {
        return true;
      }
    }
    return false;
  }

  Track? _findMatchingLocalTrack(Track onlineTrack, List<Track> localTracks) {
    for (final local in localTracks) {
      if (local.webUrl != null &&
          onlineTrack.webUrl != null &&
          local.webUrl!.trim() == onlineTrack.webUrl!.trim()) {
        return local;
      }
      if (local.id == onlineTrack.id ||
          (local.webUrl != null && local.webUrl!.contains(onlineTrack.id))) {
        return local;
      }
      final lTitle = _cleanForComparison(local.title);
      final oTitle = _cleanForComparison(onlineTrack.title);
      if (lTitle.isNotEmpty && lTitle == oTitle) {
        return local;
      }
    }
    return null;
  }

  Future<void> _downloadOnlineTrack(Track track) async {
    final folder = _downloadedFolderPath;
    HapticFeedback.lightImpact();
    UiFeedbackHelper.showSuccessToast(
      context,
      'Downloading "${track.title}" to ${widget.playlist.name}...',
    );
    await MusicDownloadManager.instance.downloadTrack(
      track,
      playlistName: widget.playlist.name,
      playlistUrl: _onlinePlaylistUrl,
      destinationDirectory: folder,
      autoPlay: false,
    );
  }

  Future<void> _downloadAllMissing(List<Track> missingTracks) async {
    if (missingTracks.isEmpty) return;
    if (MusicDownloadManager.instance.isBatchActive) {
      UiFeedbackHelper.showErrorToast(
        context,
        'A batch download is already in progress.',
      );
      return;
    }
    final folder = _downloadedFolderPath;
    HapticFeedback.lightImpact();
    UiFeedbackHelper.showSuccessToast(
      context,
      'Downloading ${missingTracks.length} missing songs to ${widget.playlist.name}...',
    );
    await MusicDownloadManager.instance.startBatchDownload(
      tracks: missingTracks,
      playlistName: widget.playlist.name,
      playlistUrl: _onlinePlaylistUrl,
      destinationDirectory: folder,
      autoPlayFirst: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLikedScreen = widget.playlist.name == 'Liked Songs';

    return ListenableBuilder(
      listenable: Listenable.merge([
        LikedSongsService.instance,
        MusicScannerService.instance.playlistsNotifier,
        MusicDownloadManager.instance,
      ]),
      builder: (context, _) {
        final currentPlaylist =
            MusicScannerService.instance.playlists.firstWhere(
          (p) =>
              p.name.trim().toLowerCase() ==
              widget.playlist.name.trim().toLowerCase(),
          orElse: () => widget.playlist,
        );

        final currentLikedIds = LikedSongsService.instance.likedIds;
        final baseTracks = isLikedScreen
            ? (MusicScannerService.instance.tracks.isNotEmpty
                ? MusicScannerService.instance.tracks
                    .where((t) => currentLikedIds.contains(t.id))
                    .toList()
                : widget.playlist.tracks
                    .where((t) => currentLikedIds.contains(t.id))
                    .toList())
            : currentPlaylist.tracks;

        final filteredDownloaded = baseTracks.where((track) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return track.title.toLowerCase().contains(q) ||
              track.artist.toLowerCase().contains(q);
        }).toList();

        final filteredOnline = (_onlineTracks ?? []).where((track) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return track.title.toLowerCase().contains(q) ||
              track.artist.toLowerCase().contains(q);
        }).toList();

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA),
          body: SafeArea(
            child: Column(
              children: [
                // Top Navigation & Playlist Header
                _buildHeader(context, isDark, baseTracks, isLikedScreen),

                // Search Bar within Playlist
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search in "${widget.playlist.name}"...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF18181B)
                          : const Color(0xFFF4F4F5),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.surfaceBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.surfaceBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),

                // Content: Downloaded Tracks and Online Playlist Section
                Expanded(
                  child: _buildScrollableContent(
                    isDark: isDark,
                    baseTracks: baseTracks,
                    filteredDownloaded: filteredDownloaded,
                    filteredOnline: filteredOnline,
                    isLikedScreen: isLikedScreen,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const SafeArea(
            top: false,
            child: MiniPlayer(),
          ),
        );
      },
    );
  }

  Widget _buildScrollableContent({
    required bool isDark,
    required List<Track> baseTracks,
    required List<Track> filteredDownloaded,
    required List<Track> filteredOnline,
    required bool isLikedScreen,
  }) {
    if (_searchQuery.isNotEmpty) {
      if (filteredDownloaded.isEmpty && filteredOnline.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.music_off_rounded,
                  size: 52,
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No songs matching "$_searchQuery"',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          if (filteredDownloaded.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Downloaded (${filteredDownloaded.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            for (var i = 0; i < filteredDownloaded.length; i++)
              _buildTrackTile(filteredDownloaded[i], i, isDark, baseTracks,
                  isLikedScreen),
          ],
          if (filteredOnline.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Online (${filteredOnline.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            for (var i = 0; i < filteredOnline.length; i++)
              _buildOnlineTrackTile(
                  filteredOnline[i], i, isDark, baseTracks),
          ],
        ],
      );
    }

    // Default view: Downloaded tracks on top, then online playlist section below
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        _buildBatchProgressBanner(isDark),

        if (baseTracks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isLikedScreen
                        ? Icons.favorite_border_rounded
                        : Icons.music_off_rounded,
                    size: 52,
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isLikedScreen
                        ? 'No liked songs yet'
                        : 'No songs downloaded in this playlist yet',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isLikedScreen) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Tap the heart icon on any song to add it to Liked Songs',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          for (var i = 0; i < baseTracks.length; i++)
            _buildTrackTile(
                baseTracks[i], i, isDark, baseTracks, isLikedScreen),

        // Online playlist expansion section
        if (!isLikedScreen) _buildOnlineSection(isDark, baseTracks),
      ],
    );
  }

  Widget _buildBatchProgressBanner(bool isDark) {
    final mgr = MusicDownloadManager.instance;
    final isThisBatch = mgr.isBatchActive &&
        (mgr.batchPlaylistName == widget.playlist.name ||
            (mgr.batchPlaylistUrl != null &&
                mgr.batchPlaylistUrl == _onlinePlaylistUrl));

    if (!isThisBatch) return const SizedBox.shrink();

    final completed = mgr.batchCompleted;
    final total = mgr.batchTotal;
    final currentTitle = mgr.batchCurrentTitle;
    final currentProgress = mgr.batchCurrentProgress;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Downloading $completed of $total tracks...',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  mgr.cancelBatchDownload();
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          if (currentTitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              currentTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: currentProgress > 0 ? currentProgress : null,
                minHeight: 4,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnlineSection(bool isDark, List<Track> baseTracks) {
    if (_onlineTracks == null && !_isFetchingOnline && _onlineError == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_download_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Download More Songs',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fetch full track list of "${widget.playlist.name}" to download remaining songs into this folder.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _fetchOnlinePlaylist(),
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Fetch All Playlist Songs'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isFetchingOnline) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fetching full playlist...',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Loading tracks from YouTube Music',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_onlineError != null && _onlineTracks == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _onlineError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _fetchOnlinePlaylist(force: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
              ),
            ),
          ],
        ),
      );
    }

    if (_onlineTracks != null) {
      final onlineList = _onlineTracks!;
      final missingTracks = onlineList
          .where((t) => !_isDownloadedLocally(t, baseTracks))
          .toList();
      final downloadedCount = onlineList.length - missingTracks.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Playlist Online',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$downloadedCount of ${onlineList.length} downloaded${missingTracks.isNotEmpty ? ' • ${missingTracks.length} available' : ' • All songs saved'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (missingTracks.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => _downloadAllMissing(missingTracks),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text('Download (${missingTracks.length})'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'All Saved',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Online tracks listing
          for (var i = 0; i < onlineList.length; i++)
            _buildOnlineTrackTile(onlineList[i], i, isDark, baseTracks),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildOnlineTrackTile(
      Track track, int index, bool isDark, List<Track> localTracks) {
    final isDownloaded = _isDownloadedLocally(track, localTracks);
    final isDownloading =
        MusicDownloadManager.instance.isDownloading(track.id);
    final progress = MusicDownloadManager.instance.getProgress(track.id);
    final localMatch = _findMatchingLocalTrack(track, localTracks);

    return ListTile(
      onTap: () {
        if (isDownloaded && localMatch != null) {
          AudioPlayerService.instance
              .playTrack(localMatch, queue: localTracks);
        } else {
          _downloadOnlineTrack(track);
        }
      },
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 42,
              height: 42,
              color: isDark
                  ? const Color(0xFF27272A)
                  : const Color(0xFFE4E4E7),
              child: _buildArtwork(track.artworkPath),
            ),
          ),
        ],
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (track.duration != null && track.duration != Duration.zero) ...[
            Text(
              track.formattedDuration,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (isDownloaded)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Saved',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else if (isDownloading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2.2,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.download_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              tooltip: 'Download to this playlist folder',
              onPressed: () => _downloadOnlineTrack(track),
            ),
        ],
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    List<Track> tracks,
    bool isLikedScreen,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button
          InkWell(
            onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'All Playlists',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Playlist Info Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: isLikedScreen
                        ? const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: !isLikedScreen
                        ? (isDark
                            ? const Color(0xFF27272A)
                            : const Color(0xFFE4E4E7))
                        : null,
                  ),
                  child: isLikedScreen
                      ? const Center(
                          child: Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        )
                      : _buildArtwork(widget.playlist.artworkPath),
                ),
              ),
              const SizedBox(width: 16),

              // Title & Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Playlist • ${tracks.length} song${tracks.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action buttons: Play All & Shuffle
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: tracks.isNotEmpty
                              ? () {
                                  AudioPlayerService.instance.playTrack(
                                    tracks.first,
                                    queue: tracks,
                                  );
                                }
                              : null,
                          icon:
                              const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Play All'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: tracks.isNotEmpty
                              ? () {
                                  final shuffled = List<Track>.from(tracks)
                                    ..shuffle();
                                  AudioPlayerService.instance.playTrack(
                                    shuffled.first,
                                    queue: shuffled,
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.shuffle_rounded, size: 16),
                          label: const Text('Shuffle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF3F3F46)
                                  : AppColors.surfaceBorder,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(
    Track track,
    int index,
    bool isDark,
    List<Track> queue,
    bool isLikedScreen,
  ) {
    return ListenableBuilder(
      listenable: AudioPlayerService.instance,
      builder: (context, _) {
        final player = AudioPlayerService.instance;
        final isCurrent = player.currentTrack?.id == track.id;
        final isLiked = LikedSongsService.instance.isLiked(track.id);

        final tile = ListTile(
          onTap: () {
            player.playTrack(
              track,
              queue: queue,
            );
          },
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                child: isCurrent
                    ? Icon(
                        Icons.equalizer_rounded,
                        color: AppColors.primary,
                        size: 20,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 42,
                  height: 42,
                  color: isDark
                      ? const Color(0xFF27272A)
                      : const Color(0xFFE4E4E7),
                  child: _buildArtwork(track.artworkPath),
                ),
              ),
            ],
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (track.duration != null && track.duration != Duration.zero)
                Text(
                  track.formattedDuration,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked
                      ? const Color(0xFFEF4444)
                      : AppColors.textMuted.withValues(alpha: 0.6),
                  size: 20,
                ),
                tooltip:
                    isLiked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
                splashRadius: 20,
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await LikedSongsService.instance.toggleLike(track.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isLiked
                              ? 'Removed "${track.title}" from Liked Songs'
                              : 'Added "${track.title}" to Liked Songs',
                        ),
                        duration: const Duration(seconds: 2),
                        action: isLiked
                            ? SnackBarAction(
                                label: 'Undo',
                                onPressed: () async {
                                  await LikedSongsService.instance
                                      .toggleLike(track.id);
                                },
                              )
                            : null,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        );

        if (!isLikedScreen) return tile;

        return Dismissible(
          key: ValueKey('liked_track_${track.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: const Color(0xFFEF4444),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.favorite_border_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
          onDismissed: (_) async {
            HapticFeedback.lightImpact();
            await LikedSongsService.instance.toggleLike(track.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${track.title}" from Liked Songs'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () async {
                      await LikedSongsService.instance.toggleLike(track.id);
                    },
                  ),
                ),
              );
            }
          },
          child: tile,
        );
      },
    );
  }

  Widget _buildArtwork(String? path) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.music_note_rounded,
        size: 24,
        color: AppColors.textSecondary.withValues(alpha: 0.6),
      ),
    );
  }
}
