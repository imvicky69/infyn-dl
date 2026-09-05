import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/services/audio_player_service.dart';
import '../../player/services/liked_songs_service.dart';
import '../../settings/services/settings_service.dart';
import '../models/music_playlist.dart';
import '../models/track.dart';
import '../services/music_scanner_service.dart';
import 'playlist_detail_screen.dart';

enum MusicLibraryViewMode { playlists, tracks }

/// Music Library screen showing scanned local audio tracks and playlists.
class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({
    super.key,
    this.onNavigateToDownloader,
  });

  final VoidCallback? onNavigateToDownloader;

  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _downloadDirectory = '';
  MusicLibraryViewMode _viewMode = MusicLibraryViewMode.playlists;
  MusicPlaylist? _selectedPlaylist;

  @override
  void initState() {
    super.initState();
    _loadDirectoryAndScan();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectoryAndScan() async {
    final dir = await SettingsService.instance.resolveDownloadDirectory();
    if (mounted) {
      setState(() {
        _downloadDirectory = dir;
      });
    }
    await MusicScannerService.instance.scanMusicDirectory();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If viewing a specific playlist, show the PlaylistDetailScreen
    if (_selectedPlaylist != null) {
      return PlaylistDetailScreen(
        playlist: _selectedPlaylist!,
        onBack: () => setState(() => _selectedPlaylist = null),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Title, Counts, Search & Rescan
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.music_note_rounded,
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
                              'Music Library',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            ValueListenableBuilder<List<Track>>(
                              valueListenable:
                                  MusicScannerService.instance.tracksNotifier,
                              builder: (context, tracks, _) {
                                final playlistCount = MusicScannerService
                                    .instance.playlists.length;
                                return Text(
                                  '$playlistCount playlists • ${tracks.length} tracks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Rescan Button
                      ValueListenableBuilder<bool>(
                        valueListenable:
                            MusicScannerService.instance.isScanningNotifier,
                        builder: (context, isScanning, _) {
                          return IconButton(
                            onPressed: isScanning
                                ? null
                                : () => MusicScannerService.instance
                                    .scanMusicDirectory(forceRefresh: true),
                            icon: isScanning
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        AppColors.primary,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.refresh_rounded,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                            tooltip: 'Rescan Music Folder',
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Segmented Switcher (Playlists vs Tracks)
                  Row(
                    children: [
                      _buildTabChip(
                        title: 'Playlists',
                        icon: Icons.queue_music_rounded,
                        isSelected: _viewMode == MusicLibraryViewMode.playlists,
                        onTap: () => setState(
                            () => _viewMode = MusicLibraryViewMode.playlists),
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        title: 'Tracks',
                        icon: Icons.audiotrack_rounded,
                        isSelected: _viewMode == MusicLibraryViewMode.tracks,
                        onTap: () => setState(
                            () => _viewMode = MusicLibraryViewMode.tracks),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: _viewMode == MusicLibraryViewMode.playlists
                          ? 'Search playlists...'
                          : 'Search songs or artists...',
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
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF141416)
                          : const Color(0xFFF4F4F5),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.surfaceBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.surfaceBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Body: Playlists View OR Tracks View
            Expanded(
              child: _viewMode == MusicLibraryViewMode.playlists
                  ? _buildPlaylistsView(isDark)
                  : _buildTracksView(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surfaceBorder.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PLAYLISTS VIEW (GRID / CARDS)
  // ==========================================
  Widget _buildPlaylistsView(bool isDark) {
    return ValueListenableBuilder<List<MusicPlaylist>>(
      valueListenable: MusicScannerService.instance.playlistsNotifier,
      builder: (context, allPlaylists, _) {
        final filteredPlaylists = allPlaylists.where((p) {
          if (_searchQuery.isEmpty) return true;
          return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        if (filteredPlaylists.isEmpty && _searchQuery.isNotEmpty) {
          return _buildEmptyState(
            isDark: isDark,
            message: 'No playlists matching "$_searchQuery"',
          );
        }

        return ValueListenableBuilder<List<Track>>(
          valueListenable: MusicScannerService.instance.tracksNotifier,
          builder: (context, allTracks, _) {
            return ListenableBuilder(
              listenable: LikedSongsService.instance,
              builder: (context, _) {
                final likedIds = LikedSongsService.instance.likedIds;
                final likedTracks = allTracks
                    .where((t) => likedIds.contains(t.id))
                    .toList();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount =
                        (constraints.maxWidth / 220).clamp(2, 6).toInt();

                    return CustomScrollView(
                      slivers: [
                        // ── Liked Songs pinned card ────────────────────────
                        if (_searchQuery.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: _buildLikedSongsCard(
                                  isDark, likedTracks, allTracks),
                            ),
                          ),

                        // ── Playlist grid ─────────────────────────────────
                        if (filteredPlaylists.isEmpty && _searchQuery.isEmpty)
                          SliverToBoxAdapter(
                            child: _buildEmptyState(
                              isDark: isDark,
                              message:
                                  'No playlists found in $_downloadDirectory',
                            ),
                          )
                        else
                          SliverPadding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 0.85,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildPlaylistCard(
                                    filteredPlaylists[index], isDark),
                                childCount: filteredPlaylists.length,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLikedSongsCard(
      bool isDark, List<Track> likedTracks, List<Track> allTracks) {
    return InkWell(
      onTap: likedTracks.isNotEmpty
          ? () {
              AudioPlayerService.instance.playTrack(
                likedTracks.first,
                queue: likedTracks,
              );
            }
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF3B0764), const Color(0xFF1E1B4B)]
                : [const Color(0xFFF3E8FF), const Color(0xFFEDE9FE)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? const Color(0xFF7C3AED).withValues(alpha: 0.4)
                : const Color(0xFFA78BFA).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFF7C3AED),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Liked Songs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFFDDD6FE)
                          : const Color(0xFF4C1D95),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    likedTracks.isEmpty
                        ? 'No liked songs yet'
                        : '${likedTracks.length} song${likedTracks.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFC4B5FD)
                          : const Color(0xFF6D28D9),
                    ),
                  ),
                ],
              ),
            ),
            if (likedTracks.isNotEmpty)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildPlaylistCard(MusicPlaylist playlist, bool isDark) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlaylist = playlist;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork / Cover
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: isDark
                            ? const Color(0xFF27272A)
                            : const Color(0xFFE4E4E7),
                        child: _buildArtwork(playlist.artworkPath),
                      ),
                    ),
                  ),
                  // Quick Play Button Overlay
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: playlist.tracks.isNotEmpty
                            ? () {
                                AudioPlayerService.instance.playTrack(
                                  playlist.tracks.first,
                                  queue: playlist.tracks,
                                );
                              }
                            : null,
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Playlist Title
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),

            // Track Count
            Text(
              '${playlist.formattedTrackCount}'
              '${playlist.formattedTotalDuration.isNotEmpty ? ' • ${playlist.formattedTotalDuration}' : ''}',
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
    );
  }

  // ==========================================
  // TRACKS VIEW (FLAT LIST)
  // ==========================================
  Widget _buildTracksView(bool isDark) {
    return ValueListenableBuilder<List<Track>>(
      valueListenable: MusicScannerService.instance.tracksNotifier,
      builder: (context, allTracks, _) {
        final filteredTracks = allTracks.where((track) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return track.title.toLowerCase().contains(q) ||
              track.artist.toLowerCase().contains(q);
        }).toList();

        if (filteredTracks.isEmpty) {
          return _buildEmptyState(
            isDark: isDark,
            message: _searchQuery.isNotEmpty
                ? 'No tracks matching "$_searchQuery"'
                : 'No audio tracks found in $_downloadDirectory',
          );
        }

        return Column(
          children: [
            // Play All & Shuffle Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      if (filteredTracks.isNotEmpty) {
                        AudioPlayerService.instance.playTrack(
                          filteredTracks.first,
                          queue: filteredTracks,
                        );
                      }
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Play All'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      if (filteredTracks.isNotEmpty) {
                        final shuffled = List<Track>.from(filteredTracks)
                          ..shuffle();
                        AudioPlayerService.instance.playTrack(
                          shuffled.first,
                          queue: shuffled,
                        );
                      }
                    },
                    icon: const Icon(Icons.shuffle_rounded, size: 16),
                    label: const Text('Shuffle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.surfaceBorder),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filteredTracks.length} tracks',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Track List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filteredTracks.length,
                itemBuilder: (context, index) {
                  final track = filteredTracks[index];
                  return _buildTrackTile(track, index, filteredTracks, isDark);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrackTile(
      Track track, int index, List<Track> queue, bool isDark) {
    return ListenableBuilder(
      listenable: AudioPlayerService.instance,
      builder: (context, _) {
        final player = AudioPlayerService.instance;
        final isCurrent = player.currentTrack?.id == track.id;

        return ListTile(
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
            track.artist + (track.album != null ? ' • ${track.album}' : ''),
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
        size: 28,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildEmptyState({required bool isDark, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_off_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            if (widget.onNavigateToDownloader != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onNavigateToDownloader,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download Music'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
