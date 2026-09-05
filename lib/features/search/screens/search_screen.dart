import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../library/models/track.dart';
import '../../player/services/audio_player_service.dart';
import '../services/ytm_search_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _results = [];
  bool _isLoading = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final results = await YtmSearchService.instance.searchTracks(query);

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _playTrack(Track track) {
    // Play immediately. StreamExtractorService handles the background extraction.
    AudioPlayerService.instance.playTrack(track, queue: _results);
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
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded,
                          size: 64, color: AppColors.surfaceBorder),
                      const SizedBox(height: 16),
                      Text(
                        'Search for songs, artists, or albums',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100), // Space for mini player
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final track = _results[index];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                      trailing: Text(
                        track.formattedDuration,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                      onTap: () => _playTrack(track),
                    );
                  },
                ),
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
