import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloader/models/download_format.dart';
import '../../downloader/models/download_item.dart';
import '../../downloader/models/download_progress.dart';
import '../../downloader/services/android_downloader_service.dart';
import '../../downloader/services/download_history_service.dart';
import '../../library/models/music_playlist.dart';
import '../../library/models/track.dart';
import '../../library/screens/playlist_detail_screen.dart';
import '../../library/services/music_scanner_service.dart';
import '../services/audio_player_service.dart';
import '../services/liked_songs_service.dart';

/// Full-screen mobile Now Playing screen styled after YouTube Music mobile.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double? _draggedPositionMs;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: AudioPlayerService.instance,
      builder: (context, _) {
        final player = AudioPlayerService.instance;
        final track = player.currentTrack;

        if (track == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final durationMs = player.duration.inMilliseconds.toDouble();
        final currentMs = _draggedPositionMs ??
            player.position.inMilliseconds
                .toDouble()
                .clamp(0.0, durationMs > 0 ? durationMs : 0.0);
        final maxMs = durationMs > 0 ? durationMs : 1.0;

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA),
          body: SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 30),
                        color: AppColors.textPrimary,
                        tooltip: 'Collapse',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PLAYING FROM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.album?.isNotEmpty == true
                                  ? track.album!
                                  : 'Offline Music Library',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showTrackOptionsSheet(context, track),
                        icon: const Icon(Icons.more_horiz_rounded, size: 24),
                        color: AppColors.textPrimary,
                        tooltip: 'Options',
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Center Album Artwork
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size =
                          (constraints.maxWidth * 0.88).clamp(240.0, 360.0);
                      return Center(
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isDark ? 0.5 : 0.15),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildArtwork(track.artworkPath, isDark),
                        ),
                      );
                    },
                  ),
                ),

                const Spacer(flex: 1),

                // Track Title & Artist with Thumbs Up
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Sleek Audio Quality & Offline Status badge (NO EMOJIS)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F1F23)
                                    : const Color(0xFFF4F4F5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.surfaceBorder,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.offline_pin_rounded,
                                    size: 13,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'OFFLINE READY',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    ' • ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    'HIGH QUALITY',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Heart / Like button
                      ListenableBuilder(
                        listenable: LikedSongsService.instance,
                        builder: (context, _) {
                          final liked =
                              LikedSongsService.instance.isLiked(track.id);
                          return IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              LikedSongsService.instance.toggleLike(track.id);
                            },
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                key: ValueKey(liked),
                                size: 24,
                                color: liked
                                    ? const Color(0xFFEF4444)
                                    : AppColors.textSecondary,
                              ),
                            ),
                            tooltip: liked ? 'Unlike' : 'Like',
                          );
                        },
                      ),
                      if (!track.isLocal && track.webUrl != null) ...[
                        const SizedBox(width: 4),
                        _isDownloading
                            ? SizedBox(
                                width: 32,
                                height: 32,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: _downloadProgress > 0
                                          ? _downloadProgress
                                          : null,
                                      strokeWidth: 2.5,
                                      color: AppColors.primary,
                                      backgroundColor: AppColors.surfaceBorder,
                                    ),
                                    Icon(Icons.download_rounded,
                                        size: 16, color: AppColors.primary),
                                  ],
                                ),
                              )
                            : IconButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Downloading "${track.title}"...')),
                                  );
                                  setState(() {
                                    _isDownloading = true;
                                    _downloadProgress = 0.0;
                                  });
                                  AndroidDownloaderService()
                                      .download(
                                    url: track.webUrl!,
                                    format: DownloadFormat.mp3,
                                  )
                                      .listen((progress) async {
                                    if (mounted) {
                                      setState(() {
                                        _downloadProgress = progress.progress;
                                      });
                                      if (progress.status ==
                                          DownloadStatus.completed) {
                                        final downloadItem = DownloadItem(
                                          id: DateTime.now()
                                              .millisecondsSinceEpoch
                                              .toString(),
                                          title: progress.title ?? track.title,
                                          url: track.webUrl ?? '',
                                          filePath:
                                              progress.outputFilePath ?? '',
                                          format: DownloadFormat.mp3,
                                          quality: 'Best (Audio)',
                                          thumbnailUrl: track.artworkPath,
                                          timestamp: DateTime.now(),
                                        );
                                        await DownloadHistoryService.instance
                                            .addDownload(downloadItem);
                                        await MusicScannerService.instance
                                            .scanMusicDirectory(
                                                forceRefresh: true);
                                        if (mounted) {
                                          setState(() {
                                            _isDownloading = false;
                                          });
                                        }
                                      } else if (progress.status ==
                                              DownloadStatus.failed ||
                                          progress.status ==
                                              DownloadStatus.cancelled) {
                                        setState(() {
                                          _isDownloading = false;
                                        });
                                      }
                                    }
                                  }, onError: (e) {
                                    if (mounted) {
                                      setState(() => _isDownloading = false);
                                    }
                                  });
                                },
                                icon: Icon(Icons.download_rounded,
                                    color: AppColors.textSecondary, size: 24),
                                tooltip: 'Download',
                              ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Seekbar / Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                            elevation: 1,
                          ),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: isDark
                              ? const Color(0xFF27272A)
                              : const Color(0xFFE4E4E7),
                          thumbColor: AppColors.primary,
                          overlayColor:
                              AppColors.primary.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          value: currentMs.clamp(0.0, maxMs),
                          min: 0.0,
                          max: maxMs,
                          onChanged: (val) {
                            setState(() {
                              _draggedPositionMs = val;
                            });
                          },
                          onChangeEnd: (val) {
                            player.seek(Duration(milliseconds: val.toInt()));
                            setState(() {
                              _draggedPositionMs = null;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(player.position),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              _formatDuration(player.duration),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Controls Row: Shuffle, Previous, Play/Pause, Next, Repeat
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Shuffle
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          player.toggleShuffle();
                        },
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: player.isShuffle
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        tooltip: 'Shuffle',
                      ),
                      // Skip Previous
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          player.skipToPrevious();
                        },
                        icon: Icon(
                          Icons.skip_previous_rounded,
                          color: AppColors.textPrimary,
                          size: 36,
                        ),
                        tooltip: 'Previous',
                      ),
                      // Play / Pause (Large Circular Button)
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            player.togglePlayPause();
                          },
                          icon: Icon(
                            player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppColors.onPrimary,
                            size: 38,
                          ),
                          tooltip: player.isPlaying ? 'Pause' : 'Play',
                        ),
                      ),
                      // Skip Next
                      IconButton(
                        onPressed: player.hasNext
                            ? () {
                                HapticFeedback.lightImpact();
                                player.skipToNext();
                              }
                            : null,
                        icon: Icon(
                          Icons.skip_next_rounded,
                          color: player.hasNext
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          size: 36,
                        ),
                        tooltip: 'Next',
                      ),
                      // Repeat
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          player.toggleRepeatMode();
                        },
                        icon: Icon(
                          player.loopMode == PlayerLoopMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: player.loopMode != PlayerLoopMode.off
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        tooltip: 'Repeat',
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Bottom Up Next Preview Drawer Handle
                _buildUpNextDrawerHandle(context, player, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpNextDrawerHandle(
    BuildContext context,
    AudioPlayerService player,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => _showQueueModal(context, player),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : const Color(0xFFF4F4F5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(
              color: AppColors.surfaceBorder,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'UP NEXT (${player.queue.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showQueueModal(BuildContext context, AudioPlayerService player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.72,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF141416) : const Color(0xFFFFFFFF),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Up Next',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${player.queue.length} tracks',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Hold to reorder',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.surfaceBorder),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: player,
                      builder: (context, _) {
                        final queue = player.queue.toList();
                        return ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: queue.length,
                          onReorderItem: (oldIndex, newIndex) {
                            player.reorderQueue(oldIndex, newIndex);
                          },
                          proxyDecorator: (child, index, animation) {
                            return Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              color: isDark
                                  ? const Color(0xFF27272A)
                                  : Colors.white,
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            final item = queue[index];
                            final isCurrent = index == player.currentIndex;

                            return Dismissible(
                              key: ValueKey('${item.filePath}_$index'),
                              direction: isCurrent
                                  ? DismissDirection.none
                                  : DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: const Color(0xFFEF4444),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              onDismissed: (_) {
                                player.removeFromQueue(index);
                              },
                              child: ListTile(
                                key: ValueKey('tile_${item.filePath}_$index'),
                                dense: true,
                                leading: isCurrent
                                    ? Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.equalizer_rounded,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                      )
                                    : Container(
                                        width: 36,
                                        height: 36,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isCurrent
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  item.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.formattedDuration,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Drag handle
                                    Icon(
                                      Icons.drag_handle_rounded,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  player.playTrack(item, queue: player.queue);
                                  Navigator.pop(ctx);
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTrackOptionsSheet(BuildContext context, Track track) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141416) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: _buildArtwork(track.artworkPath, isDark),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFEF4444),
                  ),
                  title: const Text(
                    'View Liked Songs',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Browse all your saved liked tracks',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openLikedSongsScreen(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textPrimary,
                  ),
                  title: const Text(
                    'Track Details',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    track.filePath != null
                        ? 'Local: ${track.filePath}'
                        : 'Web: ${track.id}',
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showTrackDetailsDialog(context, track);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openLikedSongsScreen(BuildContext context) {
    final allTracks = MusicScannerService.instance.tracks;
    final likedIds = LikedSongsService.instance.likedIds;
    final likedTracks =
        allTracks.where((t) => likedIds.contains(t.id)).toList();

    final likedPlaylist = MusicPlaylist(
      name: 'Liked Songs',
      tracks: likedTracks,
      artworkPath:
          likedTracks.isNotEmpty ? likedTracks.first.artworkPath : null,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(
          playlist: likedPlaylist,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _showTrackDetailsDialog(BuildContext context, Track track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Track Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Title', track.title),
            _detailRow('Artist', track.artist),
            if (track.album != null && track.album!.isNotEmpty)
              _detailRow('Album', track.album!),
            if (track.duration != null)
              _detailRow('Duration', _formatDuration(track.duration!)),
            if (track.filePath != null)
              _detailRow('File Path', track.filePath!),
            _detailRow('Format', 'MP3 Audio (Offline)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(String? path, bool isDark) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
        );
      }
    }
    return _buildPlaceholder(isDark);
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF27272A), const Color(0xFF141416)]
              : [const Color(0xFFE4E4E7), const Color(0xFFD4D4D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 72,
          color: AppColors.textSecondary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
