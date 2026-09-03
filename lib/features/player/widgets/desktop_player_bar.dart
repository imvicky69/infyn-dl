import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/audio_player_service.dart';

/// YouTube Music inspired desktop bottom playback bar.
class DesktopPlayerBar extends StatefulWidget {
  const DesktopPlayerBar({
    super.key,
    this.isPlayerScreenOpen = false,
    this.onTogglePlayerScreen,
  });

  final bool isPlayerScreenOpen;
  final VoidCallback? onTogglePlayerScreen;

  @override
  State<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _DesktopPlayerBarState extends State<DesktopPlayerBar> {
  double? _draggedPositionMs;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioPlayerService.instance,
      builder: (context, _) {
        final player = AudioPlayerService.instance;
        final track = player.currentTrack;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (track == null) {
          return const SizedBox.shrink();
        }

        final durationMs = player.duration.inMilliseconds.toDouble();
        final currentMs = _draggedPositionMs ??
            player.position.inMilliseconds
                .toDouble()
                .clamp(0.0, durationMs > 0 ? durationMs : 0.0);
        final maxMs = durationMs > 0 ? durationMs : 1.0;

        return Container(
          height: 72,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141416) : const Color(0xFFFFFFFF),
            border: Border(
              top: BorderSide(
                color: AppColors.surfaceBorder,
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top seekbar / scrubber
              SizedBox(
                height: 4,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 4.5,
                      elevation: 0,
                    ),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 8),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: isDark
                        ? const Color(0xFF27272A)
                        : const Color(0xFFE4E4E7),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.2),
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
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      // LEFT CONTROLS: Prev, Play/Pause, Next, Time
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => player.skipToPrevious(),
                            icon: Icon(
                              Icons.skip_previous_rounded,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                            splashRadius: 16,
                            tooltip: 'Previous',
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            onPressed: () => player.togglePlayPause(),
                            icon: Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.textPrimary,
                              size: 26,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            padding: EdgeInsets.zero,
                            splashRadius: 18,
                            tooltip: player.isPlaying ? 'Pause' : 'Play',
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            onPressed: player.hasNext
                                ? () => player.skipToNext()
                                : null,
                            icon: Icon(
                              Icons.skip_next_rounded,
                              color: player.hasNext
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                            splashRadius: 16,
                            tooltip: 'Next',
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatDuration(player.position)} / ${_formatDuration(player.duration)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),

                      // CENTER: Artwork Thumbnail, Title, Artist (Flexibly centered)
                      Expanded(
                        child: Center(
                          child: InkWell(
                            onTap: widget.onTogglePlayerScreen,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      color: isDark
                                          ? const Color(0xFF27272A)
                                          : const Color(0xFFE4E4E7),
                                      child: _buildArtwork(track.artworkPath),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 320),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            track.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    onPressed: () {},
                                    icon: Icon(
                                      Icons.thumb_up_alt_outlined,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                    padding: EdgeInsets.zero,
                                    splashRadius: 14,
                                    tooltip: 'Like',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // RIGHT CONTROLS: Volume, Repeat, Shuffle, Toggle Player Screen
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              player.setVolume(player.volume > 0 ? 0.0 : 1.0);
                            },
                            icon: Icon(
                              player.volume == 0
                                  ? Icons.volume_off_rounded
                                  : player.volume < 0.5
                                      ? Icons.volume_down_rounded
                                      : Icons.volume_up_rounded,
                              color: AppColors.textSecondary,
                              size: 19,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            padding: EdgeInsets.zero,
                            splashRadius: 14,
                            tooltip: player.volume == 0 ? 'Unmute' : 'Mute',
                          ),
                          SizedBox(
                            width: 76,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 3.5,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 7),
                                activeTrackColor: AppColors.textPrimary,
                                inactiveTrackColor: isDark
                                    ? const Color(0xFF27272A)
                                    : const Color(0xFFE4E4E7),
                                thumbColor: AppColors.textPrimary,
                              ),
                              child: Slider(
                                value: player.volume.clamp(0.0, 1.0),
                                min: 0.0,
                                max: 1.0,
                                onChanged: (vol) => player.setVolume(vol),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => player.toggleRepeatMode(),
                            icon: Icon(
                              player.loopMode == PlayerLoopMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              color: player.loopMode != PlayerLoopMode.off
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 19,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            padding: EdgeInsets.zero,
                            splashRadius: 14,
                            tooltip: 'Repeat',
                          ),
                          IconButton(
                            onPressed: () => player.toggleShuffle(),
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: player.isShuffle
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 19,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            padding: EdgeInsets.zero,
                            splashRadius: 14,
                            tooltip: 'Shuffle',
                          ),
                          IconButton(
                            onPressed: widget.onTogglePlayerScreen,
                            icon: Icon(
                              widget.isPlayerScreenOpen
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_up_rounded,
                              color: widget.isPlayerScreenOpen
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 22,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                            splashRadius: 16,
                            tooltip: widget.isPlayerScreenOpen
                                ? 'Close Player'
                                : 'Open Player',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
        size: 20,
        color: AppColors.textSecondary.withValues(alpha: 0.6),
      ),
    );
  }
}
