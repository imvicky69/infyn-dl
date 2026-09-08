import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../../core/theme/app_theme.dart';
import '../../downloader/models/download_format.dart';
import '../../downloader/models/download_item.dart';
import '../../downloader/models/download_progress.dart';
import '../../downloader/services/android_downloader_service.dart';
import '../../downloader/services/download_history_service.dart';
import '../../library/models/track.dart';
import '../../library/services/music_scanner_service.dart';
import '../../player/services/audio_player_service.dart';
import '../services/ytm_search_service.dart';

/// Screen allowing users to view all tracks in an online playlist or album,
/// with options to download all, select specific tracks to download,
/// and play or download individual items.
class SearchPlaylistDetailScreen extends StatefulWidget {
  const SearchPlaylistDetailScreen({
    super.key,
    required this.playlist,
  });

  final yt.SearchPlaylist playlist;

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

  // Batch download state
  bool _isBatchDownloading = false;
  int _batchCompletedCount = 0;
  int _batchTotalCount = 0;
  String _batchCurrentTitle = '';
  double _batchCurrentTrackProgress = 0.0;
  bool _cancelBatchRequested = false;
  StreamSubscription? _currentDownloadSub;

  // Single track download state
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadPercentage = {};
  final Set<String> _downloadingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchTracks();
    DownloadHistoryService.instance.changeNotifier.addListener(_onDataChanged);
    MusicScannerService.instance.tracksNotifier.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DownloadHistoryService.instance.changeNotifier
        .removeListener(_onDataChanged);
    MusicScannerService.instance.tracksNotifier.removeListener(_onDataChanged);
    _cancelBatchRequested = true;
    _currentDownloadSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchTracks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tracks = await YtmSearchService.instance
          .getPlaylistTracks(widget.playlist.id.value);
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
          if (tracks.isEmpty) {
            _errorMessage = 'No tracks found in this playlist or album.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
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
          local.title.trim().toLowerCase() == track.title.trim().toLowerCase()) {
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

    if (_downloadingIds.contains(track.id) || _isBatchDownloading) {
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
    final url = track.webUrl ?? 'https://www.youtube.com/watch?v=${track.id}';
    final playlistName = widget.playlist.title;
    final playlistUrl =
        'https://www.youtube.com/playlist?list=${widget.playlist.id.value}';

    setState(() {
      _downloadingIds.add(track.id);
      _downloadProgress[track.id] = 0.0;
      _downloadPercentage[track.id] = '0%';
    });

    StreamSubscription? sub;
    sub = AndroidDownloaderService()
        .download(
      url: url,
      format: DownloadFormat.mp3,
    )
        .listen(
      (progress) async {
        if (!mounted) return;

        setState(() {
          _downloadProgress[track.id] = progress.progress;
          _downloadPercentage[track.id] = progress.percentage;
        });

        if (progress.status == DownloadStatus.completed) {
          sub?.cancel();
          final outputFilePath = progress.outputFilePath ?? '';
          final downloadItem = DownloadItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: progress.title ?? track.title,
            url: url,
            filePath: outputFilePath,
            format: DownloadFormat.mp3,
            quality: 'Best (Audio)',
            thumbnailUrl: track.artworkPath,
            playlistName: playlistName,
            playlistUrl: playlistUrl,
            timestamp: DateTime.now(),
          );

          await DownloadHistoryService.instance.addDownload(downloadItem);
          await MusicScannerService.instance.scanMusicDirectory(forceRefresh: true);

          if (!mounted) return;
          setState(() {
            _downloadingIds.remove(track.id);
            _downloadProgress.remove(track.id);
            _downloadPercentage.remove(track.id);
          });

          final playable = Track(
            id: outputFilePath.isNotEmpty ? outputFilePath : track.id,
            title: progress.title ?? track.title,
            artist: track.artist,
            filePath: outputFilePath,
            webUrl: url,
            duration: track.duration,
            album: playlistName,
            artworkPath: track.artworkPath,
          );

          if (playable.isLocal) {
            await AudioPlayerService.instance.playTrack(
              playable,
              queue: MusicScannerService.instance.tracks,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloaded & playing "${playable.title}"'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (progress.status == DownloadStatus.failed ||
            progress.status == DownloadStatus.cancelled) {
          sub?.cancel();
          if (!mounted) return;
          setState(() {
            _downloadingIds.remove(track.id);
            _downloadProgress.remove(track.id);
            _downloadPercentage.remove(track.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Download failed: ${progress.errorMessage ?? "Unknown error"}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      onError: (err) {
        sub?.cancel();
        if (!mounted) return;
        setState(() {
          _downloadingIds.remove(track.id);
          _downloadProgress.remove(track.id);
          _downloadPercentage.remove(track.id);
        });
      },
    );
  }

  Future<void> _startBatchDownload({required List<Track> tracksToDownload}) async {
    if (tracksToDownload.isEmpty) return;

    if (_isBatchDownloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A batch download is already in progress.')),
      );
      return;
    }

    setState(() {
      _isBatchDownloading = true;
      _cancelBatchRequested = false;
      _batchCompletedCount = 0;
      _batchTotalCount = tracksToDownload.length;
      _batchCurrentTitle = tracksToDownload.first.title;
      _batchCurrentTrackProgress = 0.0;
    });

    final playlistName = widget.playlist.title;
    final playlistUrl =
        'https://www.youtube.com/playlist?list=${widget.playlist.id.value}';
    var hasStartedPlayingFirst = false;

    for (var i = 0; i < tracksToDownload.length; i++) {
      if (_cancelBatchRequested || !mounted) break;

      final track = tracksToDownload[i];
      final url = track.webUrl ?? 'https://www.youtube.com/watch?v=${track.id}';

      setState(() {
        _batchCurrentTitle = track.title;
        _batchCurrentTrackProgress = 0.0;
      });

      // Check if already downloaded
      final existing = _findLocalTrack(track);
      if (existing != null && existing.isLocal) {
        setState(() {
          _batchCompletedCount++;
        });
        if (!hasStartedPlayingFirst) {
          hasStartedPlayingFirst = true;
          AudioPlayerService.instance.playTrack(
            existing,
            queue: MusicScannerService.instance.tracks,
          );
        }
        continue;
      }

      final completer = Completer<void>();
      _currentDownloadSub = AndroidDownloaderService()
          .download(
        url: url,
        format: DownloadFormat.mp3,
      )
          .listen(
        (progress) async {
          if (!mounted) return;

          setState(() {
            _batchCurrentTrackProgress = progress.progress;
          });

          if (progress.status == DownloadStatus.completed) {
            final outputFilePath = progress.outputFilePath ?? '';
            final downloadItem = DownloadItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: progress.title ?? track.title,
              url: url,
              filePath: outputFilePath,
              format: DownloadFormat.mp3,
              quality: 'Best (Audio)',
              thumbnailUrl: track.artworkPath,
              playlistName: playlistName,
              playlistUrl: playlistUrl,
              timestamp: DateTime.now(),
            );

            await DownloadHistoryService.instance.addDownload(downloadItem);
            await MusicScannerService.instance
                .scanMusicDirectory(forceRefresh: true);

            if (mounted) {
              setState(() {
                _batchCompletedCount++;
              });

              if (!hasStartedPlayingFirst) {
                hasStartedPlayingFirst = true;
                final playable = Track(
                  id: outputFilePath.isNotEmpty ? outputFilePath : track.id,
                  title: progress.title ?? track.title,
                  artist: track.artist,
                  filePath: outputFilePath,
                  webUrl: url,
                  album: playlistName,
                  artworkPath: track.artworkPath,
                );
                if (playable.isLocal) {
                  AudioPlayerService.instance.playTrack(
                    playable,
                    queue: MusicScannerService.instance.tracks,
                  );
                }
              }
            }

            if (!completer.isCompleted) completer.complete();
          } else if (progress.status == DownloadStatus.failed ||
              progress.status == DownloadStatus.cancelled) {
            if (!completer.isCompleted) completer.complete();
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future;
      await _currentDownloadSub?.cancel();
      _currentDownloadSub = null;
    }

    if (mounted) {
      setState(() {
        _isBatchDownloading = false;
        _isSelectMode = false;
        _selectedIndices.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Batch download complete: $_batchCompletedCount / $_batchTotalCount tracks saved.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _cancelBatchDownload() {
    _cancelBatchRequested = true;
    _currentDownloadSub?.cancel();
    _currentDownloadSub = null;
    setState(() {
      _isBatchDownloading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Batch download cancelled.')),
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Fetching tracks from playlist...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
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
      bottomSheet: _isSelectMode && _selectedIndices.isNotEmpty
          ? _buildSelectedDownloadBar()
          : null,
    );
  }

  String get _displayAuthor {
    if (_tracks.isNotEmpty) {
      final firstArtist = _tracks.first.artist;
      if (firstArtist.isNotEmpty) return firstArtist;
    }
    return 'YouTube Playlist / Album';
  }

  Widget _buildPlaylistHeader() {
    final thumbUrl = widget.playlist.thumbnails.isNotEmpty
        ? widget.playlist.thumbnails.first.url.toString()
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Artwork
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 76,
              height: 76,
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

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.playlist.title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _displayAuthor,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Download All button
                FilledButton.icon(
                  onPressed: (_isBatchDownloading || _tracks.isEmpty)
                      ? null
                      : () => _startBatchDownload(tracksToDownload: _tracks),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text(
                    'Download All',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
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
    final isDownloading = _downloadingIds.contains(track.id);
    final progress = _downloadProgress[track.id] ?? 0.0;
    final percentage = _downloadPercentage[track.id] ?? '';
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
                '${index + 1}',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
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
                      final selectedTracks = _selectedIndices
                          .map((i) => _tracks[i])
                          .toList();
                      _startBatchDownload(tracksToDownload: selectedTracks);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: Text(
                'Download Selected ($selectedCount)',
                style: const TextStyle(fontWeight: FontWeight.w700),
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
