import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../library/models/track.dart';
import '../../library/services/music_scanner_service.dart';
import '../../player/services/audio_player_service.dart';
import '../../settings/services/settings_service.dart';
import '../models/download_format.dart';
import '../models/download_item.dart';
import '../models/download_progress.dart';
import 'android_downloader_service.dart';
import 'download_history_service.dart';
import 'downloader_service.dart';

/// Represents an active, in-flight music download task.
class ActiveMusicDownload {
  final String trackId;
  final String title;
  final String artist;
  final String? artworkPath;
  final String url;
  final String? playlistName;
  final String? playlistUrl;
  final bool autoPlay;
  final DateTime startedAt;

  double progress;
  String percentage;
  DownloadStatus status;
  String? errorMessage;
  String? outputFilePath;
  StreamSubscription<DownloadProgress>? subscription;

  ActiveMusicDownload({
    required this.trackId,
    required this.title,
    required this.artist,
    this.artworkPath,
    required this.url,
    this.playlistName,
    this.playlistUrl,
    this.autoPlay = false,
    required this.startedAt,
    this.progress = 0.0,
    this.percentage = '0%',
    this.status = DownloadStatus.preparing,
    this.errorMessage,
    this.outputFilePath,
    this.subscription,
  });
}

/// Centralized manager for background music downloads.
///
/// Ensures that downloads are decoupled from UI widget lifecycles.
/// Navigating away from search or playlist screens will NEVER cancel active downloads.
class MusicDownloadManager extends ChangeNotifier {
  static final MusicDownloadManager _instance =
      MusicDownloadManager._internal();

  factory MusicDownloadManager() => _instance;

  MusicDownloadManager._internal();

  static MusicDownloadManager get instance => _instance;

  DownloaderService downloaderService = AndroidDownloaderService.instance;

  final Map<String, ActiveMusicDownload> _activeDownloads = {};

  // Batch download state
  bool _isBatchActive = false;
  String? _batchPlaylistName;
  String? _batchPlaylistUrl;
  int _batchCompleted = 0;
  int _batchTotal = 0;
  double _batchCurrentProgress = 0.0;
  String _batchCurrentTitle = '';
  bool _cancelBatchRequested = false;
  StreamSubscription<DownloadProgress>? _currentBatchSub;

  Map<String, ActiveMusicDownload> get activeDownloads =>
      Map.unmodifiable(_activeDownloads);

  bool get hasActiveDownloads => _activeDownloads.isNotEmpty || _isBatchActive;
  int get activeCount => _activeDownloads.length;

  bool get isBatchActive => _isBatchActive;
  String? get batchPlaylistName => _batchPlaylistName;
  String? get batchPlaylistUrl => _batchPlaylistUrl;
  int get batchCompleted => _batchCompleted;
  int get batchTotal => _batchTotal;
  double get batchCurrentProgress => _batchCurrentProgress;
  String get batchCurrentTitle => _batchCurrentTitle;

  bool isDownloading(String trackId) => _activeDownloads.containsKey(trackId);

  ActiveMusicDownload? getDownload(String trackId) => _activeDownloads[trackId];

  double getProgress(String trackId) =>
      _activeDownloads[trackId]?.progress ?? 0.0;

  String getPercentage(String trackId) =>
      _activeDownloads[trackId]?.percentage ?? '0%';

  /// Initiates a background download for a single track.
  Future<void> downloadTrack(
    Track track, {
    String? playlistName,
    String? playlistUrl,
    bool autoPlay = false,
    String? destinationDirectory,
  }) async {
    if (_activeDownloads.containsKey(track.id)) {
      return;
    }

    final url = track.webUrl ??
        (track.id.startsWith('http')
            ? track.id
            : 'https://www.youtube.com/watch?v=${track.id}');

    final download = ActiveMusicDownload(
      trackId: track.id,
      title: track.title,
      artist: track.artist,
      artworkPath: track.artworkPath,
      url: url,
      playlistName: playlistName,
      playlistUrl: playlistUrl,
      autoPlay: autoPlay,
      startedAt: DateTime.now(),
    );

    _activeDownloads[track.id] = download;
    notifyListeners();

    try {
      final destDir = destinationDirectory ??
          await SettingsService.instance.resolveDownloadDirectory();

      final stream = downloaderService.download(
        url: url,
        format: DownloadFormat.mp3,
        destinationDirectory: destDir,
      );

      download.subscription = stream.listen(
        (event) async {
          download.progress = event.progress;
          download.percentage = event.percentage;
          download.status = event.status;

          if (event.status == DownloadStatus.completed) {
            download.outputFilePath = event.outputFilePath;
            await _finalizeDownload(download, event.title);
          } else if (event.status == DownloadStatus.failed ||
              event.status == DownloadStatus.cancelled) {
            download.errorMessage = event.errorMessage;
            _failDownload(download);
          }
          notifyListeners();
        },
        onError: (err) {
          download.errorMessage = err.toString();
          _failDownload(download);
          notifyListeners();
        },
      );
    } catch (e) {
      download.errorMessage = e.toString();
      _failDownload(download);
      notifyListeners();
    }
  }

  Future<void> _finalizeDownload(
      ActiveMusicDownload download, String? eventTitle) async {
    final outputFilePath = download.outputFilePath ?? '';
    final downloadItem = DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: eventTitle ?? download.title,
      url: download.url,
      filePath: outputFilePath,
      format: DownloadFormat.mp3,
      quality: 'Best (Audio)',
      thumbnailUrl: download.artworkPath,
      playlistName: download.playlistName,
      playlistUrl: download.playlistUrl,
      timestamp: DateTime.now(),
    );

    await DownloadHistoryService.instance.addDownload(downloadItem);
    await MusicScannerService.instance.scanMusicDirectory(forceRefresh: true);

    if (download.autoPlay && outputFilePath.isNotEmpty) {
      final playableTrack = Track(
        id: outputFilePath,
        title: eventTitle ?? download.title,
        artist: download.artist,
        filePath: outputFilePath,
        webUrl: download.url,
        album: download.playlistName,
        artworkPath: download.artworkPath,
      );
      if (playableTrack.isLocal) {
        await AudioPlayerService.instance.playTrack(
          playableTrack,
          queue: MusicScannerService.instance.tracks,
        );
      }
    }

    _activeDownloads.remove(download.trackId);
    notifyListeners();
  }

  void _failDownload(ActiveMusicDownload download) {
    download.subscription?.cancel();
    _activeDownloads.remove(download.trackId);
    notifyListeners();
  }

  /// Explicitly cancels an ongoing download for a specific track.
  Future<void> cancelDownload(String trackId) async {
    final download = _activeDownloads.remove(trackId);
    if (download != null) {
      await download.subscription?.cancel();
      notifyListeners();
    }
  }

  /// Starts a sequential batch download for a list of tracks (playlist or album).
  Future<void> startBatchDownload({
    required List<Track> tracks,
    required String playlistName,
    String? playlistUrl,
    String? destinationDirectory,
    bool autoPlayFirst = false,
  }) async {
    if (_isBatchActive) return;

    _isBatchActive = true;
    _cancelBatchRequested = false;
    _batchPlaylistName = playlistName;
    _batchPlaylistUrl = playlistUrl;
    _batchTotal = tracks.length;
    _batchCompleted = 0;
    _batchCurrentProgress = 0.0;
    _batchCurrentTitle = '';
    notifyListeners();

    var hasStartedPlayingFirst = false;

    final destDir = destinationDirectory ??
        await SettingsService.instance.resolveDownloadDirectory();

    for (var i = 0; i < tracks.length; i++) {
      if (_cancelBatchRequested) break;

      final track = tracks[i];
      _batchCurrentTitle = track.title;
      _batchCurrentProgress = 0.0;
      notifyListeners();

      // Check if already in library
      final localTracks = MusicScannerService.instance.tracks;
      final existing = localTracks.where((t) {
        if (t.id == track.id) return true;
        if (t.title.toLowerCase() == track.title.toLowerCase() &&
            t.artist.toLowerCase() == track.artist.toLowerCase()) {
          return true;
        }
        return false;
      }).firstOrNull;

      if (existing != null && existing.isLocal) {
        _batchCompleted++;
        notifyListeners();
        if (autoPlayFirst && !hasStartedPlayingFirst) {
          hasStartedPlayingFirst = true;
          AudioPlayerService.instance.playTrack(
            existing,
            queue: MusicScannerService.instance.tracks,
          );
        }
        continue;
      }

      final url = track.webUrl ??
          (track.id.startsWith('http')
              ? track.id
              : 'https://www.youtube.com/watch?v=${track.id}');

      final completer = Completer<void>();

      _currentBatchSub = downloaderService
          .download(
        url: url,
        format: DownloadFormat.mp3,
        destinationDirectory: destDir,
      )
          .listen(
        (event) async {
          _batchCurrentProgress = event.progress;
          notifyListeners();

          if (event.status == DownloadStatus.completed) {
            final outputFilePath = event.outputFilePath ?? '';
            final downloadItem = DownloadItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: event.title ?? track.title,
              url: url,
              filePath: outputFilePath,
              format: DownloadFormat.mp3,
              quality: 'Best (Audio)',
              thumbnailUrl: track.artworkPath,
              playlistName: playlistName,
              playlistUrl: playlistUrl,
              timestamp: DateTime.now(),
            );

            await DownloadHistoryService.instance.addDownload(downloadItem);
            await MusicScannerService.instance
                .scanMusicDirectory(forceRefresh: true);
            _batchCompleted++;

            if (autoPlayFirst &&
                !hasStartedPlayingFirst &&
                outputFilePath.isNotEmpty) {
              hasStartedPlayingFirst = true;
              final playable = Track(
                id: outputFilePath,
                title: event.title ?? track.title,
                artist: track.artist,
                filePath: outputFilePath,
                webUrl: url,
                album: playlistName,
                artworkPath: track.artworkPath,
              );
              if (playable.isLocal) {
                AudioPlayerService.instance.playTrack(
                  playable,
                  queue: MusicScannerService.instance.tracks,
                );
              }
            }

            if (!completer.isCompleted) completer.complete();
          } else if (event.status == DownloadStatus.failed ||
              event.status == DownloadStatus.cancelled) {
            if (!completer.isCompleted) completer.complete();
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future;
      await _currentBatchSub?.cancel();
      _currentBatchSub = null;
    }

    _isBatchActive = false;
    _batchCurrentProgress = 0.0;
    _batchCurrentTitle = '';
    notifyListeners();
  }

  /// Explicitly cancels an active batch download.
  void cancelBatchDownload() {
    _cancelBatchRequested = true;
    _currentBatchSub?.cancel();
    _currentBatchSub = null;
    _isBatchActive = false;
    _batchCurrentProgress = 0.0;
    _batchCurrentTitle = '';
    notifyListeners();
  }
}
