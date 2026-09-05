import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloader/models/download_format.dart';
import '../../downloader/models/download_progress.dart';
import '../../downloader/services/android_downloader_service.dart';
import '../../library/models/track.dart';
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
  int _searchRequestId = 0;
  final Map<String, double> _activeDownloads = {};

  Future<void> _performSearch(String query) async {
    final trimmedQuery = query.trim();
    final requestId = ++_searchRequestId;

    if (trimmedQuery.isEmpty) {
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

    try {
      if (_currentFilter == SearchFilter.songs) {
        final results = await YtmSearchService.instance.searchTracks(trimmedQuery);
        if (mounted && requestId == _searchRequestId) {
          setState(() {
            _songResults = results;
            _isLoading = false;
          });
        }
      } else {
        final results =
            await YtmSearchService.instance.searchPlaylists(trimmedQuery);
        if (mounted && requestId == _searchRequestId) {
          setState(() {
            _playlistResults = results;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Search failed. Please try again.', isError: true);
      }
    }
  }

  Future<void> _downloadTrack(Track track) async {
    final trackUrl = track.webUrl;
    if (trackUrl == null || trackUrl.trim().isEmpty) {
      _showSnackBar('Missing track URL.', isError: true);
      return;
    }

    final downloadKey = 'song:${track.id}';
    if (_activeDownloads.containsKey(downloadKey)) return;

    setState(() => _activeDownloads[downloadKey] = 0.0);
    _showSnackBar('Downloading "${track.title}"...');

    final downloader = AndroidDownloaderService();
    try {
      await for (final DownloadProgress progress in downloader.download(
        url: trackUrl,
        format: DownloadFormat.mp3,
      )) {
        if (!mounted) return;

        setState(() => _activeDownloads[downloadKey] = progress.progress);
        if (progress.isCompleted) {
          setState(() => _activeDownloads.remove(downloadKey));
          _showSnackBar('Downloaded "${track.title}"');
          return;
        }
        if (progress.isFailed || progress.isCancelled) {
          setState(() => _activeDownloads.remove(downloadKey));
          _showSnackBar(
            progress.errorMessage ?? 'Download failed for "${track.title}"',
            isError: true,
          );
          return;
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _activeDownloads.remove(downloadKey));
      _showSnackBar('Download failed for "${track.title}"', isError: true);
    }
  }

  Future<void> _downloadPlaylist(yt.SearchPlaylist playlist) async {
    final playlistUrl = playlist.url;
    final downloadKey = 'playlist:${playlist.id.value}';
    if (_activeDownloads.containsKey(downloadKey)) return;

    setState(() => _activeDownloads[downloadKey] = 0.0);
    _showSnackBar('Downloading playlist "${playlist.title}"...');

    final downloader = AndroidDownloaderService();
    try {
      await for (final DownloadProgress progress in downloader.download(
        url: playlistUrl,
        format: DownloadFormat.mp3,
      )) {
        if (!mounted) return;

        setState(() => _activeDownloads[downloadKey] = progress.progress);
        if (progress.isCompleted) {
          setState(() => _activeDownloads.remove(downloadKey));
          _showSnackBar('Playlist downloaded: "${playlist.title}"');
          return;
        }
        if (progress.isFailed || progress.isCancelled) {
          setState(() => _activeDownloads.remove(downloadKey));
          _showSnackBar(
            progress.errorMessage ?? 'Playlist download failed',
            isError: true,
          );
          return;
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _activeDownloads.remove(downloadKey));
      _showSnackBar('Playlist download failed', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
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
      trailing: _buildDownloadAction(
        key: 'song:${track.id}',
        duration: track.formattedDuration,
        tooltip: 'Download song',
      ),
      onTap: () => _downloadTrack(track),
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
      trailing: _buildDownloadAction(
        key: 'playlist:${playlist.id.value}',
        tooltip: 'Download playlist',
      ),
      onTap: () => _downloadPlaylist(playlist),
    );
  }

  Widget _buildDownloadAction({
    required String key,
    required String tooltip,
    String? duration,
  }) {
    final isDownloading = _activeDownloads.containsKey(key);
    final progress = _activeDownloads[key] ?? 0.0;
    final iconWidget = isDownloading
        ? SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
              strokeWidth: 2.4,
              color: AppColors.primary,
            ),
          )
        : Icon(
            Icons.download_rounded,
            color: AppColors.primary,
            semanticLabel: tooltip,
          );

    if (duration == null) {
      return iconWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          duration,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(width: 8),
        iconWidget,
      ],
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
