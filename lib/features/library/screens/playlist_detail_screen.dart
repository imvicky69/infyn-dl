import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/services/audio_player_service.dart';
import '../../player/services/liked_songs_service.dart';
import '../../player/widgets/mini_player.dart';
import '../models/music_playlist.dart';
import '../models/track.dart';
import '../services/music_scanner_service.dart';

/// YouTube Music style playlist detail screen.
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLikedScreen = widget.playlist.name == 'Liked Songs';

    return ListenableBuilder(
      listenable: LikedSongsService.instance,
      builder: (context, _) {
        final currentLikedIds = LikedSongsService.instance.likedIds;
        final baseTracks = isLikedScreen
            ? (MusicScannerService.instance.tracks.isNotEmpty
                ? MusicScannerService.instance.tracks
                    .where((t) => currentLikedIds.contains(t.id))
                    .toList()
                : widget.playlist.tracks
                    .where((t) => currentLikedIds.contains(t.id))
                    .toList())
            : widget.playlist.tracks;

        final filteredTracks = baseTracks.where((track) {
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

                // Track List
                Expanded(
                  child: filteredTracks.isEmpty
                      ? Center(
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
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No songs matching "$_searchQuery"'
                                      : (isLikedScreen
                                          ? 'No liked songs yet'
                                          : 'No songs in this playlist'),
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (isLikedScreen &&
                                    _searchQuery.isEmpty) ...[
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
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: filteredTracks.length,
                          itemBuilder: (context, index) {
                            final track = filteredTracks[index];
                            return _buildTrackTile(
                              track,
                              index,
                              isDark,
                              baseTracks,
                              isLikedScreen,
                            );
                          },
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
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
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
              Text(
                track.formattedDuration,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
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
