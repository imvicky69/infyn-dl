import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/utils/windows_path_helper.dart';
import '../../library/models/track.dart';

enum PlayerLoopMode { off, all, one }

/// Central audio playback controller using just_audio.
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
    } catch (e) {
      debugPrint('AudioPlayerService initialization error: $e');
    }
  }

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

      final playablePath = WindowsPathHelper.getPlayablePath(track.filePath);
      await _player?.setFilePath(playablePath);

      final loadedDuration = _player?.duration;
      if (loadedDuration != null) {
        _duration = loadedDuration;
        _currentTrack = _currentTrack?.copyWith(duration: loadedDuration);
      }

      await _player?.play();
    } catch (e) {
      debugPrint('Error playing track "${track.title}": $e');
    }
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

  /// Skips to previous track in queue or restarts current track if > 3s.
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
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _volumeSubscription?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
