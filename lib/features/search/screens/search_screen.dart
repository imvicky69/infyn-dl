import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../../core/theme/app_theme.dart';
import '../../downloader/models/download_format.dart';
import '../../downloader/models/download_item.dart';
import '../../downloader/models/download_progress.dart';
import '../../downloader/services/android_downloader_service.dart';
import '../../downloader/services/download_history_service.dart';
import '../../library/models/track.dart';
import '../../library/services/music_scanner_service.dart';
import '../../player/services/audio_player_service.dart';
import '../services/ytm_search_service.dart';
import 'search_playlist_detail_screen.dart';

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

  // Track active downloads: key is track.id or track.webUrl
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadPercentage = {};
  final Set<String> _downloadingIds = {};
  final Map<String, StreamSubscription> _downloadSubscriptions = {};

  // For playlist downloads: key is playlist id
  final Map<String, String> _playlistDownloadProgress = {};
  final Set<String> _downloadingPlaylistIds = {};

  @override
  void initState() {
    super.initState();
    DownloadHistoryService.instance.changeNotifier.addListener(_onHistoryChanged);
    MusicScannerService.instance.tracksNotifier.addListener(_onHistoryChanged);
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    DownloadHistoryService.instance.changeNotifier.removeListener(_onHistoryChanged);
    MusicScannerService.instance.tracksNotifier.removeListener(_onHistoryChanged);
    for (final sub in _downloadSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
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
      final results = await YtmSearchService.instance.searchTracks(cleanQuery);
      if (mounted) {
        setState(() {
          _songResults = results;
          _isLoading = false;
        });
      }
    } else {
      final results =
          await YtmSearchService.instance.searchPlaylists(cleanQuery);
      if (mounted) {
        setState(() {
          _playlistResults = results;
          _isLoading = false;
        });
      }
    }
  }

  /// Checks if a search track is already downloaded locally
  Track? _findLocalTrack(Track track) {
    // 1. Check in scanned music tracks
    for (final local in MusicScannerService.instance.tracks) {
      if (local.filePath == null || local.filePath!.isEmpty) continue;
      if (local.webUrl != null &&
          track.webUrl != null &&
          local.webUrl!.trim() == track.webUrl!.trim()) {
        return local;
      }
      if (local.id == track.id ||
          local.title.trim().toLowerCase() == track.title.trim().toLowerCase()) {
        if (File(local.filePath!).existsSync()) {
          return local;
        }
      }
    }
    return null;
  }

  /// Always download and play: if already downloaded, plays immediately.
  /// If not, downloads with UI feedback and auto-plays as soon as finished.
  Future<void> _handleSongTap(Track track) async {
    final localTrack = _findLocalTrack(track);
    if (localTrack != null && localTrack.isLocal) {
      // Already downloaded: play immediately
      AudioPlayerService.instance.playTrack(
        localTrack,
        queue: MusicScannerService.instance.tracks,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing "${localTrack.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // If already downloading, let the user know
    if (_downloadingIds.contains(track.id)) {
      final pct = _downloadPercentage[track.id] ?? '0%';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading "${track.title}" ($pct)...'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    // Start download & play
    await _downloadAndPlayTrack(track);
  }

  Future<void> _downloadAndPlayTrack(Track track) async {
    final url = track.webUrl ?? 'https://www.youtube.com/watch?v=${track.id}';

    setState(() {
      _downloadingIds.add(track.id);
      _downloadProgress[track.id] = 0.0;
      _downloadPercentage[track.id] = '0%';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Downloading "${track.title}"...',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    StreamSubscription? sub;
    sub = AndroidDownloaderService()
        .download(
      url: url,
      format: DownloadFormat.mp3,
    )
        .listen(
      (progress) async {
        if (!mounted) return;

        setState(() {
          _downloadProgress[track.id] = progress.progress;
          _downloadPercentage[track.id] = progress.percentage;
        });

        if (progress.status == DownloadStatus.completed) {
          sub?.cancel();
          _downloadSubscriptions.remove(track.id);

          final outputFilePath = progress.outputFilePath ?? '';
          final downloadItem = DownloadItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: progress.title ?? track.title,
            url: url,
            filePath: outputFilePath,
            format: DownloadFormat.mp3,
            quality: 'Best (Audio)',
            thumbnailUrl: track.artworkPath,
            timestamp: DateTime.now(),
          );

          await DownloadHistoryService.instance.addDownload(downloadItem);
          await MusicScannerService.instance.scanMusicDirectory(forceRefresh: true);

          if (!mounted) return;
          setState(() {
            _downloadingIds.remove(track.id);
            _downloadProgress.remove(track.id);
            _downloadPercentage.remove(track.id);
          });

          // Automatically start playing the newly downloaded track!
          final playableTrack = Track(
            id: outputFilePath.isNotEmpty ? outputFilePath : track.id,
            title: progress.title ?? track.title,
            artist: track.artist,
            filePath: outputFilePath,
            webUrl: url,
            duration: track.duration,
            artworkPath: track.artworkPath,
          );

          if (playableTrack.isLocal) {
            await AudioPlayerService.instance.playTrack(
              playableTrack,
              queue: MusicScannerService.instance.tracks,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloaded & playing "${playableTrack.title}"'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (progress.status == DownloadStatus.failed ||
            progress.status == DownloadStatus.cancelled) {
          sub?.cancel();
          _downloadSubscriptions.remove(track.id);
          if (mounted) {
            setState(() {
              _downloadingIds.remove(track.id);
              _downloadProgress.remove(track.id);
              _downloadPercentage.remove(track.id);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Download failed: ${progress.errorMessage ?? "Unknown error"}',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      onError: (err) {
        sub?.cancel();
        _downloadSubscriptions.remove(track.id);
        if (mounted) {
          setState(() {
            _downloadingIds.remove(track.id);
            _downloadProgress.remove(track.id);
            _downloadPercentage.remove(track.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download error: $err'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );

    _downloadSubscriptions[track.id] = sub;
  }

  /// Downloads all tracks in a playlist and auto-plays once the first track completes
  Future<void> _downloadPlaylist(yt.SearchPlaylist playlist) async {
    final playlistId = playlist.id.value;
    if (_downloadingPlaylistIds.contains(playlistId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playlist "${playlist.title}" is already downloading.'),
        ),
      );
      return;
    }

    setState(() {
      _downloadingPlaylistIds.add(playlistId);
      _playlistDownloadProgress[playlistId] = 'Fetching tracks...';
    });

    try {
      final tracks =
          await YtmSearchService.instance.getPlaylistTracks(playlistId);
      if (tracks.isEmpty) {
        if (mounted) {
          setState(() {
            _downloadingPlaylistIds.remove(playlistId);
            _playlistDownloadProgress.remove(playlistId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tracks found in playlist.')),
          );
        }
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Starting download for "${playlist.title}" (${tracks.length} tracks)...'),
        ),
      );

      var downloadedCount = 0;
      var hasStartedPlayingFirst = false;

      for (var i = 0; i < tracks.length; i++) {
        if (!mounted) break;
        final track = tracks[i];
        final url = track.webUrl ?? 'https://www.youtube.com/watch?v=${track.id}';

        setState(() {
          _playlistDownloadProgress[playlistId] =
              '${i + 1}/${tracks.length} (${track.title})';
        });

        // Check if already downloaded
        final existing = _findLocalTrack(track);
        if (existing != null && existing.isLocal) {
          downloadedCount++;
          if (!hasStartedPlayingFirst) {
            hasStartedPlayingFirst = true;
            AudioPlayerService.instance.playTrack(
              existing,
              queue: MusicScannerService.instance.tracks,
            );
          }
          continue;
        }

        final completer = Completer<void>();
        final sub = AndroidDownloaderService()
            .download(
          url: url,
          format: DownloadFormat.mp3,
        )
            .listen(
          (progress) async {
            if (progress.status == DownloadStatus.completed) {
              final downloadItem = DownloadItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: progress.title ?? track.title,
                url: url,
                filePath: progress.outputFilePath ?? '',
                format: DownloadFormat.mp3,
                quality: 'Best (Audio)',
                thumbnailUrl: track.artworkPath,
                playlistName: playlist.title,
                playlistUrl: 'https://www.youtube.com/playlist?list=$playlistId',
                timestamp: DateTime.now(),
              );
              await DownloadHistoryService.instance.addDownload(downloadItem);
              await MusicScannerService.instance.scanMusicDirectory(forceRefresh: true);
              downloadedCount++;

              if (!hasStartedPlayingFirst && mounted) {
                hasStartedPlayingFirst = true;
                final firstTrack = Track(
                  id: progress.outputFilePath ?? track.id,
                  title: progress.title ?? track.title,
                  artist: track.artist,
                  filePath: progress.outputFilePath,
                  webUrl: url,
                  album: playlist.title,
                  artworkPath: track.artworkPath,
                );
                if (firstTrack.isLocal) {
                  AudioPlayerService.instance.playTrack(
                    firstTrack,
                    queue: MusicScannerService.instance.tracks,
                  );
                }
              }

              if (!completer.isCompleted) completer.complete();
            } else if (progress.status == DownloadStatus.failed ||
                progress.status == DownloadStatus.cancelled) {
              if (!completer.isCompleted) completer.complete();
            }
          },
          onError: (_) {
            if (!completer.isCompleted) completer.complete();
          },
        );

        await completer.future;
        await sub.cancel();
      }

      if (mounted) {
        setState(() {
          _downloadingPlaylistIds.remove(playlistId);
          _playlistDownloadProgress.remove(playlistId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Downloaded $downloadedCount/${tracks.length} songs from "${playlist.title}"'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingPlaylistIds.remove(playlistId);
          _playlistDownloadProgress.remove(playlistId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading playlist: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
          autofocus: false,
          decoration: InputDecoration(
            hintText: 'Search YouTube Music...',
            hintStyle: TextStyle(color: AppColors.textMuted),
            border: InputBorder.none,
            prefixIcon:
                Icon(Icons.search_rounded, color: AppColors.textSecondary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17),
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
                _buildFilterChip('Playlists & Albums', SearchFilter.playlists),
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
                              'Search for songs, playlists, or albums to download & play',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 110),
                        itemCount: _currentFilter == SearchFilter.songs
                            ? _songResults.length
                            : _playlistResults.length,
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
    return _currentFilter == SearchFilter.songs
        ? _songResults.isEmpty
        : _playlistResults.isEmpty;
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
    final localTrack = _findLocalTrack(track);
    final isDownloaded = localTrack != null && localTrack.isLocal;
    final isDownloading = _downloadingIds.contains(track.id);
    final progress = _downloadProgress[track.id] ?? 0.0;
    final percentage = _downloadPercentage[track.id] ?? '';

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
          fontSize: 15,
        ),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          if (isDownloading) ...[
            const SizedBox(width: 8),
            Text(
              percentage.isNotEmpty ? percentage : 'Downloading...',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (isDownloaded) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Downloaded',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            track.formattedDuration,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(width: 8),
          if (isDownloading)
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress > 0.0 ? progress : null,
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                  Icon(
                    Icons.downloading_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            )
          else if (isDownloaded)
            IconButton(
              icon: Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              tooltip: 'Play downloaded song',
              onPressed: () => _handleSongTap(track),
            )
          else
            IconButton(
              icon: Icon(
                Icons.download_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              tooltip: 'Download & Play',
              onPressed: () => _downloadAndPlayTrack(track),
            ),
        ],
      ),
      onTap: () => _handleSongTap(track),
    );
  }

  void _openPlaylistDetail(yt.SearchPlaylist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchPlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  Widget _buildPlaylistTile(yt.SearchPlaylist playlist) {
    final playlistId = playlist.id.value;
    final isDownloading = _downloadingPlaylistIds.contains(playlistId);
    final progressStatus = _playlistDownloadProgress[playlistId];

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
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        isDownloading && progressStatus != null
            ? progressStatus
            : '${playlist.videoCount} tracks • Tap to view & download',
        style: TextStyle(
          color: isDownloading ? AppColors.primary : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: isDownloading ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isDownloading
          ? SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.download_for_offline_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  tooltip: 'Quick Download All',
                  onPressed: () => _downloadPlaylist(playlist),
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  tooltip: 'View Tracks & Select',
                  onPressed: () => _openPlaylistDetail(playlist),
                ),
              ],
            ),
      onTap: () => _openPlaylistDetail(playlist),
    );
  }

  Widget _buildFallbackArt() {
    return Container(
      width: 50,
      height: 50,
      color: AppColors.surfaceElevated,
      child: Icon(
        Icons.music_note_rounded,
        color: AppColors.textSecondary,
        size: 24,
      ),
    );
  }
}
