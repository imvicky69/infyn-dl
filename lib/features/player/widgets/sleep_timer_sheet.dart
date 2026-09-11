import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../services/sleep_timer_service.dart';

/// Modern, interactive Sleep Timer bottom sheet with quick presets,
/// custom slider, end-of-track option, and live countdown.
class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SleepTimerSheet(),
    );
  }

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  double _selectedMinutes = 30.0;
  bool _isEndOfTrackSelected = false;
  late bool _fadeAudio;

  final List<int> _presetMinutes = [15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _fadeAudio = SleepTimerService.instance.fadeAudio;
  }

  String _formatTargetTime(int minutesFromNow) {
    final target = DateTime.now().add(Duration(minutes: minutesFromNow));
    final hour = target.hour == 0
        ? 12
        : (target.hour > 12 ? target.hour - 12 : target.hour);
    final minute = target.minute.toString().padLeft(2, '0');
    final period = target.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              SleepTimerService.instance.isRunningNotifier,
              SleepTimerService.instance.remainingNotifier,
              SleepTimerService.instance.isEndOfTrackNotifier,
            ]),
            builder: (context, _) {
              final isRunning = SleepTimerService.instance.isRunning;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bedtime_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sleep Timer',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              isRunning
                                  ? 'Active • Music will turn off automatically'
                                  : 'Fall asleep peacefully to your favorite tracks',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Body Content: Active vs Inactive
                  if (isRunning)
                    _buildActiveState(isDark)
                  else
                    _buildInactiveState(isDark),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ACTIVE TIMER VIEW
  // ==========================================
  Widget _buildActiveState(bool isDark) {
    final timerService = SleepTimerService.instance;
    final remaining = timerService.remaining;
    final isEndOfTrack = timerService.isEndOfTrack;

    return Column(
      children: [
        // Glowing Countdown Display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.06)
                : AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.onPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isEndOfTrack
                    ? 'End of Current Track'
                    : timerService.formatRemaining(remaining),
                style: TextStyle(
                  fontSize: isEndOfTrack ? 22 : 44,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: isEndOfTrack ? 0 : 1.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEndOfTrack
                    ? 'Playback will stop when the current song completes'
                    : 'Time remaining until music pauses',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Quick Extend Buttons (only for timed mode)
        if (!isEndOfTrack) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    timerService.addMinutes(5);
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+5 Min'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF3F3F46)
                          : AppColors.surfaceBorder,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    timerService.addMinutes(15);
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+15 Min'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF3F3F46)
                          : AppColors.surfaceBorder,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // Turn Off Timer Button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              timerService.cancelTimer();
            },
            icon: const Icon(Icons.timer_off_rounded, size: 18),
            label: const Text(
              'Turn Off Timer',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF27272A)
                  : const Color(0xFFE4E4E7),
              foregroundColor: isDark
                  ? const Color(0xFFFAFAFA)
                  : const Color(0xFF09090B),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // INACTIVE TIMER SETUP VIEW
  // ==========================================
  Widget _buildInactiveState(bool isDark) {
    return Column(
      children: [
        // Central Display Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1B1E) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
            ),
          ),
          child: Column(
            children: [
              if (_isEndOfTrackSelected) ...[
                Icon(Icons.queue_music_rounded,
                    size: 36, color: AppColors.primary),
                const SizedBox(height: 8),
                Text(
                  'End of Track',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stop playback after current song finishes',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_selectedMinutes.toInt()}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'MIN',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Music pauses at ${_formatTargetTime(_selectedMinutes.toInt())}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Slider (disabled if End of Track is active)
        if (!_isEndOfTrackSelected) ...[
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: isDark
                  ? const Color(0xFF27272A)
                  : const Color(0xFFE4E4E7),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.15),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
                elevation: 3,
              ),
            ),
            child: Slider(
              value: _selectedMinutes,
              min: 5.0,
              max: 120.0,
              divisions: 23, // 5 min steps
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedMinutes = val;
                  _isEndOfTrackSelected = false;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5m',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
                Text('60m',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
                Text('120m',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Quick Preset Chips (15m, 30m, 45m, 60m, End of Track)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._presetMinutes.map((m) {
                final isSelected =
                    !_isEndOfTrackSelected && _selectedMinutes.toInt() == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${m}m'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedMinutes = m.toDouble();
                          _isEndOfTrackSelected = false;
                        });
                      }
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.textPrimary,
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF1F1F23)
                        : const Color(0xFFF4F4F5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? const Color(0xFF27272A)
                                : AppColors.surfaceBorder),
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }),
              ChoiceChip(
                avatar: Icon(
                  Icons.audiotrack_rounded,
                  size: 15,
                  color: _isEndOfTrackSelected
                      ? AppColors.onPrimary
                      : AppColors.textSecondary,
                ),
                label: const Text('End of Track'),
                selected: _isEndOfTrackSelected,
                onSelected: (selected) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isEndOfTrackSelected = selected;
                  });
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _isEndOfTrackSelected
                      ? AppColors.onPrimary
                      : AppColors.textPrimary,
                ),
                backgroundColor:
                    isDark ? const Color(0xFF1F1F23) : const Color(0xFFF4F4F5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: _isEndOfTrackSelected
                        ? AppColors.primary
                        : (isDark
                            ? const Color(0xFF27272A)
                            : AppColors.surfaceBorder),
                  ),
                ),
                showCheckmark: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Smooth Audio Fade-Out Switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
            ),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _fadeAudio,
            activeThumbColor: AppColors.primary,
            title: Text(
              'Smooth audio fade-out',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Gradually lowers volume in the final 20 seconds',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            onChanged: (val) {
              setState(() => _fadeAudio = val);
              SleepTimerService.instance.setFadeAudio(val);
            },
          ),
        ),

        const SizedBox(height: 20),

        // Start Sleep Timer Button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              if (_isEndOfTrackSelected) {
                SleepTimerService.instance.startEndOfTrackTimer(
                  fadeAudio: _fadeAudio,
                );
              } else {
                SleepTimerService.instance.startTimer(
                  Duration(minutes: _selectedMinutes.toInt()),
                  fadeAudio: _fadeAudio,
                );
              }
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              _isEndOfTrackSelected
                  ? 'Start Timer (End of Track)'
                  : 'Start Sleep Timer (${_selectedMinutes.toInt()} min)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
