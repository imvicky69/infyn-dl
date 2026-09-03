import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/audio_player_service.dart';

/// Full-screen mobile Now Playing screen styled after YouTube Music mobile.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double? _draggedPositionMs;

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
                      const Spacer(),
                      // "Song" / "Video" pill toggle (Song active)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1F1F23)
                              : const Color(0xFFE4E4E7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF27272A)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Song',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Text(
                                'Video',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.more_vert_rounded, size: 22),
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.thumb_up_alt_outlined, size: 22),
                        color: AppColors.textSecondary,
                        tooltip: 'Like',
                      ),
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
                        onPressed: () => player.toggleShuffle(),
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
                        onPressed: () => player.skipToPrevious(),
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
                          onPressed: () => player.togglePlayPause(),
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
                        onPressed:
                            player.hasNext ? () => player.skipToNext() : null,
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
                        onPressed: () => player.toggleRepeatMode(),
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
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141416) : const Color(0xFFFFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
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
                      'Up Next Queue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${player.queue.length} tracks',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: player.queue.length,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemBuilder: (context, index) {
                    final item = player.queue[index];
                    final isCurrent = index == player.currentIndex;

                    return ListTile(
                      dense: true,
                      leading: isCurrent
                          ? Icon(Icons.equalizer_rounded,
                              color: AppColors.primary, size: 20)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w500,
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
                      trailing: Text(
                        item.formattedDuration,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onTap: () {
                        player.playTrack(item, queue: player.queue);
                        Navigator.pop(ctx);
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
