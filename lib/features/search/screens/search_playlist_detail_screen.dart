import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_feedback_helper.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../../downloader/services/download_history_service.dart';
import '../../downloader/services/music_download_manager.dart';
import '../../library/models/track.dart';
import '../../library/services/music_scanner_service.dart';
import '../../player/services/audio_player_service.dart';
import '../../player/widgets/mini_player.dart';
import '../models/search_playlist_info.dart';
import '../services/ytm_search_service.dart';

/// Screen allowing users to view all tracks in an online playlist or album,
/// with options to download all, select specific tracks to download,
/// and play or download individual items.
class SearchPlaylistDetailScreen extends StatefulWidget {
  const SearchPlaylistDetailScreen({
    super.key,
    required this.playlist,
  });

  final SearchPlaylistInfo playlist;

  @override
  State<SearchPlaylistDetailScreen> createState() =>
      _SearchPlaylistDetailScreenState();
}

class _SearchPlaylistDetailScreenState
    extends State<SearchPlaylistDetailScreen> {
  List<Track> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Multi-select mode
  bool _isSelectMode = false;
  final Set<int> _selectedIndices = {};

  // Batch download state read directly from persistent background manager
  bool get _isBatchDownloading =>
      MusicDownloadManager.instance.isBatchActive &&
      MusicDownloadManager.instance.batchPlaylistName == widget.playlist.title;
  int get _batchCompletedCount => MusicDownloadManager.instance.batchCompleted;
  int get _batchTotalCount => MusicDownloadManager.instance.batchTotal;
  String get _batchCurrentTitle =>
      MusicDownloadManager.instance.batchCurrentTitle;
  double get _batchCurrentTrackProgress =>
      MusicDownloadManager.instance.batchCurrentProgress;

  @override
  void initState() {
    super.initState();
    final syncCached = YtmSearchService.instance
        .getCachedPlaylistTracksSync(widget.playlist.id);
    if (syncCached != null && syncCached.isNotEmpty) {
      _tracks = syncCached;
      _isLoading = false;
    }
    _fetchTracks(hasCached: syncCached != null && syncCached.isNotEmpty);
    DownloadHistoryService.instance.changeNotifier.addListener(_onDataChanged);
    MusicScannerService.instance.tracksNotifier.addListener(_onDataChanged);
    MusicDownloadManager.instance.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DownloadHistoryService.instance.changeNotifier
        .removeListener(_onDataChanged);
    MusicScannerService.instance.tracksNotifier.removeListener(_onDataChanged);
    MusicDownloadManager.instance.removeListener(_onDataChanged);
    // NOTE: We do NOT cancel the batch or single download here!
    // Background downloads continue seamlessly through MusicDownloadManager.
    super.dispose();
  }

  Future<void> _fetchTracks(
      {bool hasCached = false, bool force = false}) async {
    if (force) {
      setState(() {
        _isLoading = _tracks.isEmpty;
        _errorMessage = null;
      });
    } else if (!hasCached) {
      final asyncCached = await YtmSearchService.instance
          .getCachedPlaylistTracks(widget.playlist.id);
      if (asyncCached != null && asyncCached.isNotEmpty && mounted) {
        setState(() {
          _tracks = asyncCached;
          _isLoading = false;
        });
        hasCached = true;
      }
    }

    if (!hasCached && !force && _tracks.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final tracks = await YtmSearchService.instance
          .getPlaylistTracks(widget.playlist.id, forceRefresh: force);
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
          if (tracks.isEmpty && _tracks.isEmpty) {
            _errorMessage = 'No tracks found in this playlist or album.';
          }
        });
      }
    } catch (e) {
      if (mounted && _tracks.isEmpty) {
        setState(() {
          _errorMessage = 'Failed to load tracks: $e';
          _isLoading = false;
        });
      }
    }
  }

  Track? _findLocalTrack(Track track) {
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

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndices.length == _tracks.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.clear();
        for (var i = 0; i < _tracks.length; i++) {
          _selectedIndices.add(i);
        }
      }
    });
  }

  void _toggleIndex(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  Future<void> _handleTrackTap(Track track, int index) async {
    if (_isSelectMode) {
      _toggleIndex(index);
      return;
    }

    final localTrack = _findLocalTrack(track);
    if (localTrack != null && localTrack.isLocal) {
      // Play local track immediately
      await AudioPlayerService.instance.playTrack(
        localTrack,
        queue: MusicScannerService.instance.tracks,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing "${localTrack.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (MusicDownloadManager.instance.isDownloading(track.id) ||
        _isBatchDownloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download already in progress for "${track.title}"'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    await _downloadSingleTrack(track);
  }

  Future<void> _downloadSingleTrack(Track track) async {
    HapticFeedback.lightImpact();
    UiFeedbackHelper.showSuccessToast(
      context,
      'Downloading "${track.title}" in background...',
    );
    await MusicDownloadManager.instance.downloadTrack(
      track,
      playlistName: widget.playlist.title,
      playlistUrl:
          'https://www.youtube.com/playlist?list=${widget.playlist.id}',
      autoPlay: true,
    );
  }

  Future<void> _startBatchDownload(
      {required List<Track> tracksToDownload}) async {
    if (tracksToDownload.isEmpty) return;

    if (_isBatchDownloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('A batch download is already in progress.')),
      );
      return;
    }

    final playlistName = widget.playlist.title;
    final playlistUrl =
        'https://www.youtube.com/playlist?list=${widget.playlist.id}';

    UiFeedbackHelper.showSuccessToast(
      context,
      'Starting batch download of ${tracksToDownload.length} tracks...',
    );

    setState(() {
      _isSelectMode = false;
      _selectedIndices.clear();
    });

    // Delegate batch to background manager so navigating back will NOT cancel it!
    MusicDownloadManager.instance.startBatchDownload(
      tracks: tracksToDownload,
      playlistName: playlistName,
      playlistUrl: playlistUrl,
      autoPlayFirst: true,
    );
  }

  void _cancelBatchDownload() {
    MusicDownloadManager.instance.cancelBatchDownload();
    UiFeedbackHelper.showErrorToast(
      context,
      'Batch download cancelled.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Playlist Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Refresh Tracks',
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetchTracks(force: true);
            },
          ),
          if (_tracks.isNotEmpty)
            IconButton(
              icon: Icon(
                _isSelectMode
                    ? Icons.check_circle_rounded
                    : Icons.checklist_rounded,
                color:
                    _isSelectMode ? AppColors.primary : AppColors.textSecondary,
              ),
              tooltip: _isSelectMode ? 'Exit Selection' : 'Select Tracks',
              onPressed: () {
                setState(() {
                  _isSelectMode = !_isSelectMode;
                  _selectedIndices.clear();
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? ShimmerLoading(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        ShimmerBox(width: 96, height: 96, borderRadius: 14),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBox(
                                  width: double.infinity,
                                  height: 16,
                                  borderRadius: 4),
                              SizedBox(height: 8),
                              ShimmerBox(
                                  width: 140, height: 12, borderRadius: 4),
                              SizedBox(height: 12),
                              ShimmerBox(
                                  width: 100, height: 28, borderRadius: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(7, (_) => const TrackSkeletonTile()),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _fetchTracks,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Header Card
                    _buildPlaylistHeader(),

                    // Active Batch Download Banner
                    if (_isBatchDownloading) _buildBatchProgressBanner(),

                    // Track count & selection controls
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            '${_tracks.length} Tracks',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (_isSelectMode) ...[
                            TextButton.icon(
                              onPressed: _toggleSelectAll,
                              icon: Icon(
                                _selectedIndices.length == _tracks.length
                                    ? Icons.deselect_rounded
                                    : Icons.select_all_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _selectedIndices.length == _tracks.length
                                    ? 'Deselect All'
                                    : 'Select All',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Tracks List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: _tracks.length,
                        itemBuilder: (context, index) {
                          final track = _tracks[index];
                          return _buildTrackTile(track, index);
                        },
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSelectMode && _selectedIndices.isNotEmpty)
              _buildSelectedDownloadBar(),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }

  String get _displayAuthor {
    if (widget.playlist.author != null && widget.playlist.author!.isNotEmpty) {
      return widget.playlist.author!;
    }
    if (_tracks.isNotEmpty) {
      final firstArtist = _tracks.first.artist;
      if (firstArtist.isNotEmpty) return firstArtist;
    }
    return 'YouTube Playlist / Album';
  }

  String get _formattedTotalDuration {
    var totalSeconds = 0;
    for (final t in _tracks) {
      if (t.duration != null) {
        totalSeconds += t.duration!.inSeconds;
      }
    }
    if (totalSeconds == 0) return '';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}'.trim();
    }
    return '$minutes min';
  }

  Widget _buildPlaylistHeader() {
    final thumbUrl = widget.playlist.thumbnailUrl;
    final durationStr = _formattedTotalDuration;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Large cover art
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: thumbUrl != null
                      ? Image.network(
                          thumbUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildFallbackArt(),
                        )
                      : _buildFallbackArt(),
                ),
              ),
              const SizedBox(width: 14),

              // Title and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _displayAuthor,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.audiotrack_rounded,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_tracks.length} tracks',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (durationStr.isNotEmpty) ...[
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            durationStr,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.playlist.genres.isNotEmpty ||
              widget.playlist.languages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...widget.playlist.genres.map((g) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        g,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    )),
                ...widget.playlist.languages.map((l) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )),
              ],
            ),
          ],
          if (widget.playlist.description != null &&
              widget.playlist.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.playlist.description!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),

          // Primary Actions
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_isBatchDownloading || _tracks.isEmpty)
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _startBatchDownload(tracksToDownload: _tracks);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text(
                    'Download All',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _tracks.isEmpty
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isSelectMode = !_isSelectMode;
                          _selectedIndices.clear();
                        });
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _isSelectMode ? AppColors.primary : AppColors.textPrimary,
                  side: BorderSide(
                    color: _isSelectMode
                        ? AppColors.primary
                        : AppColors.surfaceBorder,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  _isSelectMode ? Icons.close_rounded : Icons.checklist_rounded,
                  size: 18,
                ),
                label: Text(
                  _isSelectMode ? 'Cancel' : 'Select',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchProgressBanner() {
    final ratio = _batchTotalCount > 0
        ? (_batchCompletedCount / _batchTotalCount).clamp(0.0, 1.0)
        : 0.0;
    final pct = (ratio * 100).toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Downloading $_batchCompletedCount / $_batchTotalCount tracks ($pct%)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _cancelBatchDownload,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: AppColors.surfaceBorder,
              color: AppColors.primary,
            ),
          ),
          if (_batchCurrentTitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Current: $_batchCurrentTitle',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_batchCurrentTrackProgress > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${(_batchCurrentTrackProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackTile(Track track, int index) {
    final localTrack = _findLocalTrack(track);
    final isDownloaded = localTrack != null && localTrack.isLocal;
    final isDownloading = MusicDownloadManager.instance.isDownloading(track.id);
    final progress = MusicDownloadManager.instance.getProgress(track.id);
    final percentage = MusicDownloadManager.instance.getPercentage(track.id);
    final isSelected = _selectedIndices.contains(index);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSelectMode)
            Checkbox(
              value: isSelected,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (_) => _toggleIndex(index),
            )
          else
            SizedBox(
              width: 24,
              child: Text(
                (index + 1).toString().padLeft(2, '0'),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: track.hasArtwork
                ? Image.network(
                    track.artworkPath!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackArt(),
                  )
                : _buildFallbackArt(),
          ),
        ],
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
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
      trailing: _isSelectMode
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.formattedDuration,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(width: 6),
                if (isDownloading)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      value: progress > 0.0 ? progress : null,
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  )
                else if (isDownloaded)
                  IconButton(
                    icon: Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                    tooltip: 'Play',
                    onPressed: () => _handleTrackTap(track, index),
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.download_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    tooltip: 'Download & Play',
                    onPressed: () => _downloadSingleTrack(track),
                  ),
              ],
            ),
      onTap: () => _handleTrackTap(track, index),
    );
  }

  Widget _buildSelectedDownloadBar() {
    final selectedCount = _selectedIndices.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.checklist_rtl_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$selectedCount ${selectedCount == 1 ? "track" : "tracks"} selected',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _isBatchDownloading
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      final selectedTracks =
                          _selectedIndices.map((i) => _tracks[i]).toList();
                      _startBatchDownload(tracksToDownload: selectedTracks);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(
                'Download ($selectedCount)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackArt() {
    return Container(
      width: 44,
      height: 44,
      color: AppColors.surfaceElevated,
      child: Icon(
        Icons.music_note_rounded,
        color: AppColors.textSecondary,
        size: 20,
      ),
    );
  }
}
