import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/services/audio_player_service.dart';
import '../../player/services/liked_songs_service.dart';
import '../../settings/services/settings_service.dart';
import '../models/music_playlist.dart';
import '../models/track.dart';
import '../services/music_scanner_service.dart';
import 'playlist_detail_screen.dart';
import '../../home/models/catalog_playlist.dart';
import '../../home/services/catalog_service.dart';
import '../../search/screens/search_playlist_detail_screen.dart';
import '../../player/services/recently_played_service.dart';

enum MusicLibraryViewMode { playlists, tracks }

enum TrackSortOption { recent, titleAZ, artist, duration }

/// Music Library screen showing scanned local audio tracks and playlists.
class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({
    super.key,
    this.onNavigateToDownloader,
    this.onNavigateToSearch,
  });

  final VoidCallback? onNavigateToDownloader;
  final VoidCallback? onNavigateToSearch;

  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _downloadDirectory = '';
  MusicLibraryViewMode _viewMode = MusicLibraryViewMode.playlists;
  TrackSortOption _sortOption = TrackSortOption.recent;

  List<Track> _sortTracks(List<Track> list) {
    final copy = List<Track>.from(list);
    switch (_sortOption) {
      case TrackSortOption.titleAZ:
        copy.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case TrackSortOption.artist:
        copy.sort(
            (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case TrackSortOption.duration:
        copy.sort((a, b) =>
            (b.duration?.inSeconds ?? 0).compareTo(a.duration?.inSeconds ?? 0));
        break;
      case TrackSortOption.recent:
        break;
    }
    return copy;
  }

  @override
  void initState() {
    super.initState();
    _loadDirectoryAndScan();
    CatalogService.instance.init();
    RecentlyPlayedService.instance.init();
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/logo-clear.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
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
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => MusicScannerService.instance
                    .scanMusicDirectory(forceRefresh: true),
                child: _viewMode == MusicLibraryViewMode.playlists
                    ? _buildPlaylistsView(isDark)
                    : _buildTracksView(isDark),
              ),
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
                final likedTracks =
                    allTracks.where((t) => likedIds.contains(t.id)).toList();

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
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: _buildLikedSongsCard(
                                  isDark, likedTracks, allTracks),
                            ),
                          ),

                        // ── Recently Played quick resume ──────────────────
                        if (_searchQuery.isEmpty)
                          SliverToBoxAdapter(
                            child: _buildRecentlyPlayedSection(isDark),
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
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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

                        // ── Featured Playlists (Curated Discovery) ─────────
                        if (_searchQuery.isEmpty)
                          SliverToBoxAdapter(
                            child: _buildFeaturedPlaylistsSection(isDark),
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
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(
                    playlist: MusicPlaylist(
                      name: 'Liked Songs',
                      tracks: likedTracks,
                      artworkPath: likedTracks.isNotEmpty
                          ? likedTracks.first.artworkPath
                          : null,
                    ),
                  ),
                ),
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
                        : '${likedTracks.length} song${likedTracks.length == 1 ? '' : 's'} • Tap to view all',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFC4B5FD)
                          : const Color(0xFF6D28D9),
                    ),
                  ),
                ],
              ),
            ),
            if (likedTracks.isNotEmpty)
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  AudioPlayerService.instance.playTrack(
                    likedTracks.first,
                    queue: likedTracks,
                  );
                },
                icon: Container(
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
                tooltip: 'Play all liked songs',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(MusicPlaylist playlist, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(
              playlist: playlist,
            ),
          ),
        );
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
          if (_searchQuery.isNotEmpty) {
            return _buildEmptyState(
              isDark: isDark,
              message: 'No tracks matching "$_searchQuery"',
            );
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildEmptyState(
                  isDark: isDark,
                  message: 'No audio tracks found in $_downloadDirectory',
                ),
                _buildFeaturedPlaylistsSection(isDark),
              ],
            ),
          );
        }

        final sortedTracks = _sortTracks(filteredTracks);

        return Column(
          children: [
            // Play All & Shuffle Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      if (sortedTracks.isNotEmpty) {
                        HapticFeedback.lightImpact();
                        AudioPlayerService.instance.playTrack(
                          sortedTracks.first,
                          queue: sortedTracks,
                        );
                      }
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Play All'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
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
                      if (sortedTracks.isNotEmpty) {
                        HapticFeedback.lightImpact();
                        final shuffled = List<Track>.from(sortedTracks)
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
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF3F3F46)
                            : AppColors.surfaceBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.sort_rounded, size: 20),
                    tooltip: 'Sort tracks',
                    onPressed: () => _showSortModal(context),
                  ),
                  Text(
                    '${sortedTracks.length} tracks',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Track List with Featured Playlists footer
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: sortedTracks.length + (_searchQuery.isEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < sortedTracks.length) {
                    final track = sortedTracks[index];
                    return _buildTrackTile(track, index, sortedTracks, isDark);
                  }
                  return _buildFeaturedPlaylistsSection(isDark);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSortModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(
                  'Sort Tracks By',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Divider(height: 16),
              _sortTile(ctx, 'Recently Added', TrackSortOption.recent,
                  Icons.schedule_rounded),
              _sortTile(ctx, 'Title (A to Z)', TrackSortOption.titleAZ,
                  Icons.sort_by_alpha_rounded),
              _sortTile(ctx, 'Artist Name', TrackSortOption.artist,
                  Icons.person_rounded),
              _sortTile(ctx, 'Duration (Longest first)',
                  TrackSortOption.duration, Icons.timelapse_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(
      BuildContext ctx, String title, TrackSortOption option, IconData icon) {
    final isSelected = _sortOption == option;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          size: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: AppColors.primary, size: 20)
          : null,
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _sortOption = option);
        Navigator.of(ctx).pop();
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

  Widget _buildEmptyState({
    required bool isDark,
    required String message,
    String? title,
    String? subtitle,
  }) {
    final isSearchFilter = _searchQuery.isNotEmpty;
    final displayTitle =
        title ?? (isSearchFilter ? 'No results found' : 'No music yet');
    final displaySubtitle = subtitle ??
        (isSearchFilter
            ? message
            : 'Search for music or paste a YouTube link to start downloading.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearchFilter
                    ? Icons.search_off_rounded
                    : Icons.music_note_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displaySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (!isSearchFilter) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (widget.onNavigateToSearch != null)
                    FilledButton.icon(
                      onPressed: widget.onNavigateToSearch,
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Search Music'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  if (widget.onNavigateToDownloader != null)
                    OutlinedButton.icon(
                      onPressed: widget.onNavigateToDownloader,
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Paste Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF3F3F46)
                              : AppColors.surfaceBorder,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FEATURED PLAYLISTS (CURATED DISCOVERY)
  // ==========================================
  Widget _buildFeaturedPlaylistsSection(bool isDark) {
    return ValueListenableBuilder<List<CatalogPlaylist>>(
      valueListenable: CatalogService.instance.playlistsNotifier,
      builder: (context, playlists, _) {
        if (playlists.isEmpty) return const SizedBox.shrink();

        final featured = playlists.where((p) => p.featured).toList();
        final displayList = featured.isNotEmpty ? featured : playlists;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Featured Playlists',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Curated for you • Tap to preview & download',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Clean non-horizontal layout: vertical list on mobile, 2-column grid on desktop
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                if (isWide) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: displayList.map((playlist) {
                        final itemWidth = (constraints.maxWidth - 32 - 12) / 2;
                        return SizedBox(
                          width: itemWidth,
                          child: _buildFeaturedPlaylistTile(playlist, isDark),
                        );
                      }).toList(),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildFeaturedPlaylistTile(displayList[index], isDark),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedPlaylistTile(CatalogPlaylist playlist, bool isDark) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SearchPlaylistDetailScreen(
              playlist: playlist.toSearchPlaylistInfo(),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: playlist.thumbnailUrl != null &&
                              playlist.thumbnailUrl!.isNotEmpty
                          ? Image.network(
                              playlist.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark
                                    ? const Color(0xFF27272A)
                                    : const Color(0xFFE4E4E7),
                                child: Icon(
                                  Icons.album_rounded,
                                  color: AppColors.textSecondary,
                                  size: 28,
                                ),
                              ),
                            )
                          : Container(
                              color: isDark
                                  ? const Color(0xFF27272A)
                                  : const Color(0xFFE4E4E7),
                              child: Icon(
                                Icons.album_rounded,
                                color: AppColors.textSecondary,
                                size: 28,
                              ),
                            ),
                    ),
                    if (playlist.trackCount != null && playlist.trackCount! > 0)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_note,
                                  size: 9, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                '${playlist.trackCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${playlist.author ?? 'YouTube Music'} • ${playlist.trackCount ?? 0} songs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  if (playlist.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      playlist.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Trailing arrow / preview button
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // RECENTLY PLAYED SECTION
  // ==========================================
  Widget _buildRecentlyPlayedSection(bool isDark) {
    return ValueListenableBuilder<List<Track>>(
      valueListenable: RecentlyPlayedService.instance.recentlyPlayedNotifier,
      builder: (context, recentTracks, _) {
        if (recentTracks.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Recently Played',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recentTracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final track = recentTracks[index];
                  return _buildRecentTrackCard(track, recentTracks, isDark);
                },
              ),
            ),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }

  Widget _buildRecentTrackCard(Track track, List<Track> queue, bool isDark) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        AudioPlayerService.instance.playTrack(track, queue: queue);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 190,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: track.artworkPath != null &&
                        track.artworkPath!.isNotEmpty
                    ? (track.artworkPath!.startsWith('http')
                        ? Image.network(
                            track.artworkPath!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildFallbackCover(),
                          )
                        : (File(track.artworkPath!).existsSync()
                            ? Image.file(
                                File(track.artworkPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildFallbackCover(),
                              )
                            : _buildFallbackCover()))
                    : _buildFallbackCover(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCover() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        size: 22,
        color: AppColors.textSecondary,
      ),
    );
  }
}
