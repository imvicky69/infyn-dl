import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_player_service.dart';

/// Service managing the Sleep Timer feature: countdown timer, end-of-track mode,
/// and smooth audio attenuation/fade out.
class SleepTimerService {
  static SleepTimerService? _instance;
  static SleepTimerService get instance => _instance ??= SleepTimerService._();

  SleepTimerService._();

  Timer? _countdownTicker;
  DateTime? _targetEndTime;
  Duration? _initialDuration;
  bool _fadeAudio = true;
  double _preFadeVolume = 1.0;
  VoidCallback? _playerListener;

  final ValueNotifier<bool> isRunningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration?> remainingNotifier =
      ValueNotifier<Duration?>(null);
  final ValueNotifier<Duration?> totalDurationNotifier =
      ValueNotifier<Duration?>(null);
  final ValueNotifier<bool> isEndOfTrackNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> fadeAudioNotifier = ValueNotifier<bool>(true);

  bool get isRunning => isRunningNotifier.value;
  Duration? get remaining => remainingNotifier.value;
  bool get isEndOfTrack => isEndOfTrackNotifier.value;
  bool get fadeAudio => fadeAudioNotifier.value;

  void setFadeAudio(bool value) {
    _fadeAudio = value;
    fadeAudioNotifier.value = value;
  }

  /// Starts a countdown timer for the specified duration.
  void startTimer(Duration duration, {bool? fadeAudio}) {
    cancelTimer();

    if (fadeAudio != null) {
      setFadeAudio(fadeAudio);
    }

    _initialDuration = duration;
    _targetEndTime = DateTime.now().add(duration);
    _preFadeVolume = AudioPlayerService.instance.volume;

    isRunningNotifier.value = true;
    isEndOfTrackNotifier.value = false;
    totalDurationNotifier.value = duration;
    remainingNotifier.value = duration;

    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick();
    });
  }

  /// Sets the timer to automatically pause playback as soon as the current track completes.
  void startEndOfTrackTimer({bool? fadeAudio}) {
    cancelTimer();

    if (fadeAudio != null) {
      setFadeAudio(fadeAudio);
    }

    final player = AudioPlayerService.instance;
    final currentTrackId = player.currentTrack?.id;
    if (currentTrackId == null) return;

    _preFadeVolume = player.volume;

    isRunningNotifier.value = true;
    isEndOfTrackNotifier.value = true;
    totalDurationNotifier.value = null;

    final remainingTrackTime = player.duration > player.position
        ? player.duration - player.position
        : Duration.zero;
    remainingNotifier.value = remainingTrackTime;

    _playerListener = () {
      final current = player.currentTrack?.id;
      if (current != currentTrackId || !player.isPlaying) {
        _triggerSleepTimer();
      } else {
        final rem = player.duration > player.position
            ? player.duration - player.position
            : Duration.zero;
        remainingNotifier.value = rem;

        if (_fadeAudio && rem.inSeconds <= 15 && rem.inSeconds > 0) {
          final factor = (rem.inSeconds / 15.0).clamp(0.05, 1.0);
          player.setVolume(_preFadeVolume * factor);
        }
      }
    };

    player.addListener(_playerListener!);
  }

  void _tick() {
    if (_targetEndTime == null) {
      cancelTimer();
      return;
    }

    final now = DateTime.now();
    final rem = _targetEndTime!.difference(now);

    if (rem.isNegative || rem.inSeconds <= 0) {
      remainingNotifier.value = Duration.zero;
      _triggerSleepTimer();
      return;
    }

    remainingNotifier.value = rem;

    // Smooth audio fade out in final 20 seconds
    if (_fadeAudio && rem.inSeconds <= 20) {
      final factor = (rem.inSeconds / 20.0).clamp(0.05, 1.0);
      AudioPlayerService.instance.setVolume(_preFadeVolume * factor);
    }
  }

  Future<void> _triggerSleepTimer() async {
    cancelTimer(restoreVolume: false);
    await AudioPlayerService.instance.pause();
    await AudioPlayerService.instance.setVolume(_preFadeVolume);
  }

  /// Extends the active timer by the given number of minutes.
  void addMinutes(int minutes) {
    if (!isRunning || _targetEndTime == null) return;
    final extension = Duration(minutes: minutes);
    _targetEndTime = _targetEndTime!.add(extension);
    final newTotal = (_initialDuration ?? Duration.zero) + extension;
    _initialDuration = newTotal;
    totalDurationNotifier.value = newTotal;
    remainingNotifier.value = _targetEndTime!.difference(DateTime.now());
  }

  /// Cancels any active sleep timer and restores volume if needed.
  void cancelTimer({bool restoreVolume = true}) {
    _countdownTicker?.cancel();
    _countdownTicker = null;
    if (_playerListener != null) {
      AudioPlayerService.instance.removeListener(_playerListener!);
      _playerListener = null;
    }
    _targetEndTime = null;
    _initialDuration = null;

    isRunningNotifier.value = false;
    isEndOfTrackNotifier.value = false;
    remainingNotifier.value = null;
    totalDurationNotifier.value = null;

    if (restoreVolume) {
      AudioPlayerService.instance.setVolume(_preFadeVolume);
    }
  }

  /// Formats remaining duration e.g. "24:18" or "1h 15m".
  String formatRemaining(Duration? duration) {
    if (duration == null) return '';
    if (isEndOfTrack) return 'End of track';

    final totalSeconds = duration.inSeconds;
    if (totalSeconds < 0) return '0:00';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
