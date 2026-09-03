import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/audio_player_service.dart';

/// YouTube Music inspired Desktop Player View (Center Artwork + Right UP NEXT Queue).
class DesktopPlayerScreen extends StatefulWidget {
  const DesktopPlayerScreen({
    super.key,
    this.onClose,
  });

  final VoidCallback? onClose;

  @override
  State<DesktopPlayerScreen> createState() => _DesktopPlayerScreenState();
}

class _DesktopPlayerScreenState extends State<DesktopPlayerScreen> {
  int _selectedTab = 0; // 0: UP NEXT, 1: LYRICS, 2: RELATED

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: AudioPlayerService.instance,
      builder: (context, _) {
        final player = AudioPlayerService.instance;
        final track = player.currentTrack;

        if (track == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.music_note_rounded,
                  size: 64,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'No track selected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a track from the library to start playback',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }

        return Row(
          children: [
            // CENTER: Song/Video switcher + Large Album Art
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // "Song" / "Video" pill toggle
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
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF27272A) : Colors.white,
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
                              horizontal: 14, vertical: 6),
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

                  // Large Album Artwork
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Container(
                            constraints: const BoxConstraints(
                              maxWidth: 440,
                              maxHeight: 440,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: isDark ? 0.6 : 0.2),
                                  blurRadius: 36,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildArtwork(track.artworkPath, isDark),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // RIGHT PANEL: UP NEXT / LYRICS / RELATED
            Container(
              width: 400,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.surfaceBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        _buildTabButton('UP NEXT', 0),
                        const SizedBox(width: 8),
                        _buildTabButton('LYRICS', 1),
                        const SizedBox(width: 8),
                        _buildTabButton('RELATED', 2),
                      ],
                    ),
                  ),

                  // Subheader
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Playing from',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.album ?? 'Local Music Library',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Tab content
                  Expanded(
                    child: _selectedTab == 0
                        ? _buildUpNextQueue(player, isDark)
                        : _buildPlaceholderTab(
                            _selectedTab == 1 ? 'Lyrics' : 'Related'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildUpNextQueue(AudioPlayerService player, bool isDark) {
    final queue = player.queue;
    if (queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final item = queue[index];
        final isCurrent = index == player.currentIndex;

        return Material(
          color: isCurrent
              ? (isDark ? const Color(0xFF1F1F23) : const Color(0xFFF4F4F5))
              : Colors.transparent,
          child: InkWell(
            onTap: () => player.playTrack(item, queue: queue),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Play indicator or Thumbnail
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 44,
                          height: 44,
                          color: isDark
                              ? const Color(0xFF27272A)
                              : const Color(0xFFE4E4E7),
                          child: _buildSmallThumbnail(item.artworkPath),
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Title and Artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
                        const SizedBox(height: 2),
                        Text(
                          item.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Duration
                  Text(
                    item.formattedDuration,
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
        );
      },
    );
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 36, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            '$title will be available in future updates',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallThumbnail(String? path) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _smallPlaceholder(),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _smallPlaceholder(),
        );
      }
    }
    return _smallPlaceholder();
  }

  Widget _smallPlaceholder() {
    return Center(
      child: Icon(
        Icons.music_note_rounded,
        size: 20,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
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
          size: 96,
          color: AppColors.textSecondary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
