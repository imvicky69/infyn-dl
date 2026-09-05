import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../library/models/track.dart';
import '../../library/services/music_scanner_service.dart';
import 'stream_extractor_service.dart';

enum PlayerLoopMode { off, all, one }

/// Central audio playback controller using just_audio.
/// Persists last state (track, queue, position, shuffle, loop) across restarts.
class AudioPlayerService extends ChangeNotifier {
  static AudioPlayerService? _instance;
  static AudioPlayerService get instance =>
      _instance ??= AudioPlayerService._();

  AudioPlayerService._() {
    _initPlayer();
  }

  AudioPlayer? _player;

  Track? _currentTrack;
  List<Track> _queue = [];
  List<Track> _originalQueue = [];
  int _currentIndex = -1;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  double _volume = 1.0;
  bool _isShuffle = false;
  PlayerLoopMode _loopMode = PlayerLoopMode.off;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<double>? _volumeSubscription;

  // Persistence debounce timer
  Timer? _persistDebounce;

  // Getters
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  double get volume => _volume;
  bool get isShuffle => _isShuffle;
  PlayerLoopMode get loopMode => _loopMode;
  bool get hasPrevious => _currentIndex > 0 || _position.inSeconds > 3;
  bool get hasNext =>
      _queue.isNotEmpty &&
      (_currentIndex < _queue.length - 1 || _loopMode == PlayerLoopMode.all);

  void _initPlayer() {
    try {
      final player = AudioPlayer();
      _player = player;

      _playerStateSubscription = player.playerStateStream.listen((state) {
        final wasPlaying = _isPlaying;
        _isPlaying = state.playing;
        _isBuffering = state.processingState == ProcessingState.buffering ||
            state.processingState == ProcessingState.loading;

        if (state.processingState == ProcessingState.completed) {
          _handleTrackCompleted();
        }

        if (wasPlaying != _isPlaying || _isBuffering) {
          notifyListeners();
        }
      });

      _positionSubscription = player.positionStream.listen((pos) {
        _position = pos;
        notifyListeners();
        _scheduleStatePersist();
      });

      _durationSubscription = player.durationStream.listen((dur) {
        if (dur != null && dur != Duration.zero) {
          _duration = dur;
          if (_currentTrack != null && _currentTrack!.duration == null) {
            _currentTrack = _currentTrack!.copyWith(duration: dur);
          }
          notifyListeners();
        }
      });

      _volumeSubscription = player.volumeStream.listen((vol) {
        _volume = vol.clamp(0.0, 1.0);
        notifyListeners();
      });

      // Restore last state after player is ready
      _restoreLastState();
    } catch (e) {
      debugPrint('AudioPlayerService initialization error: $e');
    }
  }

  // ── State persistence ────────────────────────────────────────────────────────

  static const String _kLastTrackId = 'player_last_track_id';
  static const String _kLastQueueIds = 'player_last_queue_ids';
  static const String _kLastPosition = 'player_last_position_ms';
  static const String _kLastShuffle = 'player_last_shuffle';
  static const String _kLastLoop = 'player_last_loop';
  static const String _kLastIndex = 'player_last_index';

  void _scheduleStatePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 3), _persistState);
  }

  Future<void> _persistState() async {
    if (_currentTrack == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastTrackId, _currentTrack!.id);
      await prefs.setStringList(
          _kLastQueueIds, _queue.map((t) => t.id).toList());
      await prefs.setInt(_kLastPosition, _position.inMilliseconds);
      await prefs.setBool(_kLastShuffle, _isShuffle);
      await prefs.setInt(_kLastLoop, _loopMode.index);
      await prefs.setInt(_kLastIndex, _currentIndex);
    } catch (e) {
      debugPrint('AudioPlayerService._persistState error: $e');
    }
  }

  Future<void> _restoreLastState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTrackId = prefs.getString(_kLastTrackId);
      if (lastTrackId == null) return;

      final queueIds = prefs.getStringList(_kLastQueueIds) ?? [];
      final positionMs = prefs.getInt(_kLastPosition) ?? 0;
      final shuffle = prefs.getBool(_kLastShuffle) ?? false;
      final loopIndex = prefs.getInt(_kLastLoop) ?? 0;
      final savedIndex = prefs.getInt(_kLastIndex) ?? 0;

      // Wait for scanner to populate tracks
      await Future.delayed(const Duration(milliseconds: 300));
      final allTracks = MusicScannerService.instance.tracksNotifier.value;

      // Build track lookup by ID
      final byId = {for (final t in allTracks) t.id: t};

      final restoredQueue = queueIds
          .map((p) => byId[p])
          .whereType<Track>()
          .toList();

      if (restoredQueue.isEmpty) return;

      final restoredTrack = byId[lastTrackId];
      if (restoredTrack == null) return;

      _isShuffle = shuffle;
      _loopMode = PlayerLoopMode.values[loopIndex.clamp(0, PlayerLoopMode.values.length - 1)];
      _originalQueue = List<Track>.from(restoredQueue);
      _queue = List<Track>.from(restoredQueue);
      _currentIndex = savedIndex.clamp(0, _queue.length - 1);
      _currentTrack = restoredTrack;
      _position = Duration(milliseconds: positionMs);
      _duration = restoredTrack.duration ?? Duration.zero;

      // Load audio but do NOT auto-play
      if (restoredTrack.isLocal) {
        await _player?.setFilePath(restoredTrack.filePath!);
      } else {
        final streamUrl = await StreamExtractorService.instance.getStreamUrl(restoredTrack);
        if (streamUrl != null) {
          await _player?.setUrl(streamUrl);
        }
      }
      if (positionMs > 0) {
        await _player?.seek(Duration(milliseconds: positionMs));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('AudioPlayerService._restoreLastState error: $e');
    }
  }

  // ── Playback ─────────────────────────────────────────────────────────────────

  /// Plays a track and optionally updates the playback queue.
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    try {
      if (queue != null && queue.isNotEmpty) {
        _originalQueue = List<Track>.from(queue);
        if (_isShuffle) {
          _queue = _createShuffledQueue(_originalQueue, track);
        } else {
          _queue = List<Track>.from(_originalQueue);
        }
      } else if (_queue.isEmpty || !_queue.contains(track)) {
        _originalQueue = [track];
        _queue = [track];
      }

      _currentIndex = _queue.indexOf(track);
      if (_currentIndex == -1) {
        _queue.insert(0, track);
        _currentIndex = 0;
      }

      _currentTrack = track;
      _position = Duration.zero;
      _duration = track.duration ?? Duration.zero;
      notifyListeners();

      try {
      if (track.isLocal) {
        await _player?.setAudioSource(
          AudioSource.uri(
            Uri.parse(track.filePath!),
            tag: MediaItem(
              id: track.id,
              title: track.title,
              artist: track.artist,
              artUri: track.artworkPath != null ? Uri.parse(track.artworkPath!) : null,
            ),
          ),
        );
      } else {
        _isBuffering = true;
        notifyListeners();
        
        final streamUrl = await StreamExtractorService.instance.getStreamUrl(track);
        if (streamUrl != null) {
          await _player?.setAudioSource(
            AudioSource.uri(
              Uri.parse(streamUrl),
              tag: MediaItem(
                id: track.id,
                title: track.title,
                artist: track.artist,
                artUri: track.artworkPath != null ? Uri.parse(track.artworkPath!) : null,
              ),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              },
            ),
          );
        } else {
          // Extraction failed
          _isBuffering = false;
          notifyListeners();
          return;
        }
      }

        final loadedDuration = _player?.duration;
        if (loadedDuration != null) {
          _duration = loadedDuration;
          _currentTrack = _currentTrack?.copyWith(duration: loadedDuration);
        }

        await _player?.play();
        await _persistState();
      } catch (e) {
        debugPrint('Error playing track: $e');
        _isBuffering = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error playing track "${track.title}": $e');
    }
  }

  /// Reorders a track in the queue. Called by ReorderableListView drag.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (newIndex > oldIndex) newIndex--;

    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);

    // Update current index to follow the currently playing track
    if (_currentTrack != null) {
      _currentIndex = _queue.indexOf(_currentTrack!);
    }

    notifyListeners();
    _persistState();
  }

  /// Removes a track from the queue (cannot remove currently playing track).
  void removeFromQueue(int index) {
    if (index == _currentIndex) return; // can't remove current
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    }
    notifyListeners();
    _persistState();
  }

  /// Toggles play/pause.
  Future<void> togglePlayPause() async {
    if (_currentTrack == null) return;
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    if (_currentTrack == null && _queue.isNotEmpty) {
      await playTrack(_queue.first);
      return;
    }
    await _player?.play();
  }

  Future<void> pause() async {
    await _player?.pause();
    await _persistState();
  }

  Future<void> seek(Duration targetPosition) async {
    final clamped = Duration(
      milliseconds: targetPosition.inMilliseconds.clamp(
          0,
          _duration.inMilliseconds > 0
              ? _duration.inMilliseconds
              : targetPosition.inMilliseconds),
    );
    _position = clamped;
    notifyListeners();
    await _player?.seek(clamped);
  }

  /// Skips to next track in queue.
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;

    if (_loopMode == PlayerLoopMode.one) {
      await seek(Duration.zero);
      await play();
      return;
    }

    if (_currentIndex < _queue.length - 1) {
      final nextTrack = _queue[_currentIndex + 1];
      await playTrack(nextTrack);
    } else if (_loopMode == PlayerLoopMode.all) {
      final firstTrack = _queue.first;
      await playTrack(firstTrack);
    } else {
      await pause();
      await seek(Duration.zero);
    }
  }

  /// Skips to previous track in queue or restarts current track if >3s.
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_currentIndex > 0) {
      final prevTrack = _queue[_currentIndex - 1];
      await playTrack(prevTrack);
    } else if (_loopMode == PlayerLoopMode.all) {
      final lastTrack = _queue.last;
      await playTrack(lastTrack);
    } else {
      await seek(Duration.zero);
    }
  }

  /// Sets player volume between 0.0 and 1.0.
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    _volume = clamped;
    notifyListeners();
    await _player?.setVolume(clamped);
  }

  /// Toggles shuffle mode.
  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle && _currentTrack != null) {
      _queue = _createShuffledQueue(_originalQueue, _currentTrack!);
      _currentIndex = _queue.indexOf(_currentTrack!);
    } else {
      _queue = List<Track>.from(_originalQueue);
      if (_currentTrack != null) {
        _currentIndex = _queue.indexOf(_currentTrack!);
      }
    }
    notifyListeners();
    _persistState();
  }

  List<Track> _createShuffledQueue(List<Track> list, Track current) {
    final remaining = list.where((t) => t != current).toList();
    remaining.shuffle(Random());
    return [current, ...remaining];
  }

  /// Cycles loop mode: off -> all -> one -> off.
  void toggleLoopMode() {
    switch (_loopMode) {
      case PlayerLoopMode.off:
        _loopMode = PlayerLoopMode.all;
        break;
      case PlayerLoopMode.all:
        _loopMode = PlayerLoopMode.one;
        break;
      case PlayerLoopMode.one:
        _loopMode = PlayerLoopMode.off;
        break;
    }
    notifyListeners();
    _persistState();
  }

  void toggleRepeatMode() => toggleLoopMode();

  void _handleTrackCompleted() {
    if (_loopMode == PlayerLoopMode.one) {
      seek(Duration.zero);
      play();
    } else {
      skipToNext();
    }
  }

  Future<void> stop() async {
    await _player?.stop();
    _currentTrack = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _volumeSubscription?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
