import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/services/audio_player_service.dart';
import '../models/music_playlist.dart';
import '../models/track.dart';

/// YouTube Music style playlist detail screen.
class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.onBack,
  });

  final MusicPlaylist playlist;
  final VoidCallback onBack;

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
    final filteredTracks = widget.playlist.tracks.where((track) {
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
            _buildHeader(context, isDark),

            // Search Bar within Playlist
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No songs matching "$_searchQuery"'
                            : 'No songs in this playlist',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: filteredTracks.length,
                      itemBuilder: (context, index) {
                        final track = filteredTracks[index];
                        return _buildTrackTile(track, index, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
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
            onTap: widget.onBack,
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
                  color: isDark
                      ? const Color(0xFF27272A)
                      : const Color(0xFFE4E4E7),
                  child: _buildArtwork(widget.playlist.artworkPath),
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
                      'Playlist • ${widget.playlist.formattedTrackCount}'
                      '${widget.playlist.formattedTotalDuration.isNotEmpty ? ' • ${widget.playlist.formattedTotalDuration}' : ''}',
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
                          onPressed: widget.playlist.tracks.isNotEmpty
                              ? () {
                                  AudioPlayerService.instance.playTrack(
                                    widget.playlist.tracks.first,
                                    queue: widget.playlist.tracks,
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Play All'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: widget.playlist.tracks.isNotEmpty
                              ? () {
                                  final shuffled =
                                      List<Track>.from(widget.playlist.tracks)
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
                            side: BorderSide(color: AppColors.surfaceBorder),
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

  Widget _buildTrackTile(Track track, int index, bool isDark) {
    return ListenableBuilder(
      listenable: AudioPlayerService.instance,
      builder: (context, _) {
        final player = AudioPlayerService.instance;
        final isCurrent = player.currentTrack?.id == track.id;

        return ListTile(
          onTap: () {
            player.playTrack(
              track,
              queue: widget.playlist.tracks,
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
          trailing: Text(
            track.formattedDuration,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
