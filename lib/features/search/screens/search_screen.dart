import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../library/models/track.dart';
import '../../player/services/audio_player_service.dart';
import '../services/ytm_search_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum SearchFilter { songs, playlists }

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _songResults = [];
  List<yt.SearchPlaylist> _playlistResults = [];
  bool _isLoading = false;
  SearchFilter _currentFilter = SearchFilter.songs;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _songResults = [];
        _playlistResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (_currentFilter == SearchFilter.songs) {
      final results = await YtmSearchService.instance.searchTracks(query);
      if (mounted) {
        setState(() {
          _songResults = results;
          _isLoading = false;
        });
      }
    } else {
      final results = await YtmSearchService.instance.searchPlaylists(query);
      if (mounted) {
        setState(() {
          _playlistResults = results;
          _isLoading = false;
        });
      }
    }
  }

  void _playTrack(Track track) {
    AudioPlayerService.instance.playTrack(track, queue: _songResults);
  }

  Future<void> _playPlaylist(yt.SearchPlaylist playlist) async {
    setState(() => _isLoading = true);
    final tracks = await YtmSearchService.instance.getPlaylistTracks(playlist.id.value);
    if (mounted) {
      setState(() => _isLoading = false);
      if (tracks.isNotEmpty) {
        AudioPlayerService.instance.playTrack(tracks.first, queue: tracks);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playing playlist: ${playlist.title}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search YouTube Music...',
            hintStyle: TextStyle(color: AppColors.textMuted),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
              onPressed: () => _performSearch(_searchController.text),
            ),
          ),
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
          onSubmitted: _performSearch,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Songs', SearchFilter.songs),
                const SizedBox(width: 8),
                _buildFilterChip('Playlists', SearchFilter.playlists),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _isEmptyResults()
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded,
                                size: 64, color: AppColors.surfaceBorder),
                            const SizedBox(height: 16),
                            Text(
                              'Search for songs or playlists',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: _currentFilter == SearchFilter.songs ? _songResults.length : _playlistResults.length,
                        itemBuilder: (context, index) {
                          if (_currentFilter == SearchFilter.songs) {
                            final track = _songResults[index];
                            return _buildSongTile(track);
                          } else {
                            final playlist = _playlistResults[index];
                            return _buildPlaylistTile(playlist);
                          }
                        },
                      ),
          ),
        ],
      ),
    );
  }

  bool _isEmptyResults() {
    return _currentFilter == SearchFilter.songs ? _songResults.isEmpty : _playlistResults.isEmpty;
  }

  Widget _buildFilterChip(String label, SearchFilter filter) {
    final isSelected = _currentFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected && _currentFilter != filter) {
          setState(() => _currentFilter = filter);
          if (_searchController.text.isNotEmpty) {
            _performSearch(_searchController.text);
          }
        }
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSongTile(Track track) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: track.hasArtwork
            ? Image.network(
                track.artworkPath!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackArt(),
              )
            : _buildFallbackArt(),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: Text(
        track.formattedDuration,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      onTap: () => _playTrack(track),
    );
  }

  Widget _buildPlaylistTile(yt.SearchPlaylist playlist) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: playlist.thumbnails.isNotEmpty
            ? Image.network(
                playlist.thumbnails.first.url.toString(),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackArt(),
              )
            : _buildFallbackArt(),
      ),
      title: Text(
        playlist.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15),
      ),
      subtitle: Text(
        '${playlist.videoCount} tracks',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: Icon(Icons.play_circle_fill_rounded, color: AppColors.primary),
      onTap: () => _playPlaylist(playlist),
    );
  }

  Widget _buildFallbackArt() {
    return Container(
      width: 50,
      height: 50,
      color: AppColors.surfaceElevated,
      child: Icon(Icons.music_note_rounded,
          color: AppColors.textSecondary, size: 24),
    );
  }
}
