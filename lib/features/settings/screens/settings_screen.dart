import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloader/services/android_downloader_service.dart';
import '../../downloader/services/downloader_service.dart';
import '../services/settings_service.dart';

/// Clean, user-friendly settings screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.downloaderService,
  });

  final DownloaderService? downloaderService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final DownloaderService _downloaderService;
  String _currentDownloadDir = 'Loading...';
  bool _autoSkip = true;
  bool _playlistSubfolder = true;
  int _concurrentDownloads = 3;
  bool _isUpdatingEngine = false;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _downloaderService = widget.downloaderService ?? AndroidDownloaderService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await SettingsService.instance.init();
      final dir = await SettingsService.instance.resolveDownloadDirectory();
      if (mounted) {
        setState(() {
          _currentDownloadDir = dir;
          _autoSkip = SettingsService.instance.autoSkipDuplicates;
          _playlistSubfolder = SettingsService.instance.playlistSubfolder;
          _concurrentDownloads = SettingsService.instance.concurrentDownloads;
          _themeMode = SettingsService.instance.themeMode;
        });
      }
    } catch (e) {
      debugPrint('SettingsScreen._loadSettings error: $e');
    }
  }

  Future<void> _handleUpdateEngine() async {
    if (_isUpdatingEngine) return;
    setState(() => _isUpdatingEngine = true);
    try {
      final s = _downloaderService;
      final androidService =
          s is AndroidDownloaderService ? s : AndroidDownloaderService();
      final result = await androidService.updateEngine();
      if (mounted) {
        _showSnackbar(result ?? 'Engine updated successfully');
        await _loadSettings();
      }
    } catch (e) {
      if (mounted) _showSnackbar('Update failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingEngine = false);
    }
  }

  Future<void> _pickDirectory() async {
    try {
      final selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Download Destination Folder',
      );
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        await SettingsService.instance.setCustomDownloadPath(selectedDirectory);
        final resolved =
            await SettingsService.instance.resolveDownloadDirectory();
        if (mounted) {
          setState(() => _currentDownloadDir = resolved);
          _showSnackbar('Download folder updated');
        }
      }
    } catch (e) {
      _showSnackbar('Could not open folder picker: $e', isError: true);
    }
  }

  Future<void> _resetDefaultDirectory() async {
    await SettingsService.instance.setCustomDownloadPath(null);
    final resolved = await SettingsService.instance.resolveDownloadDirectory();
    if (mounted) {
      setState(() => _currentDownloadDir = resolved);
      _showSnackbar('Reset to default folder');
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Appearance ────────────────────────────────────────────────────
          _sectionLabel('APPEARANCE'),
          const SizedBox(height: 8),
          _card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: _iconBox(
                _themeMode == ThemeMode.dark ||
                        (_themeMode == ThemeMode.system && isDark)
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
              ),
              title: Text('Theme',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              subtitle: Text(
                _themeMode == ThemeMode.dark
                    ? 'Dark'
                    : (_themeMode == ThemeMode.light
                        ? 'Light'
                        : 'Follow system'),
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              trailing: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded, size: 16),
                      tooltip: 'Light'),
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded, size: 16),
                      tooltip: 'System'),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded, size: 16),
                      tooltip: 'Dark'),
                ],
                selected: {_themeMode},
                onSelectionChanged: (s) async {
                  final mode = s.first;
                  setState(() => _themeMode = mode);
                  await SettingsService.instance.setThemeMode(mode);
                },
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: AppColors.onPrimary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Download Folder ───────────────────────────────────────────────
          _sectionLabel('DOWNLOAD FOLDER'),
          const SizedBox(height: 8),
          _card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _iconBox(Icons.folder_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentDownloadDir,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _pickDirectory,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.drive_file_move_rounded,
                              size: 16),
                          label: const Text('Change Folder',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      if (SettingsService.instance.customDownloadPath !=
                          null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _resetDefaultDirectory,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side:
                                BorderSide(color: AppColors.surfaceBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          child: const Text('Reset',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Downloads ────────────────────────────────────────────────────
          _sectionLabel('DOWNLOADS'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _autoSkip,
                  activeThumbColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  title: Text('Skip Already Downloaded',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  subtitle: Text(
                      'Automatically skip songs already in your library',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  onChanged: (val) async {
                    await SettingsService.instance
                        .setAutoSkipDuplicates(val);
                    setState(() => _autoSkip = val);
                  },
                ),
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.surfaceBorder),
                SwitchListTile(
                  value: _playlistSubfolder,
                  activeThumbColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  title: Text('Playlist Subfolders',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  subtitle: Text(
                      'Save playlist songs into a folder named after the playlist',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  onChanged: (val) async {
                    await SettingsService.instance
                        .setPlaylistSubfolder(val);
                    setState(() => _playlistSubfolder = val);
                  },
                ),
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.surfaceBorder),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Parallel Downloads',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${_concurrentDownloads}x',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'Download multiple tracks at once from a playlist',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      Row(
                        children: [1, 2, 3, 4, 5].map((count) {
                          final sel = _concurrentDownloads == count;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3),
                              child: InkWell(
                                onTap: () async {
                                  await SettingsService.instance
                                      .setConcurrentDownloads(count);
                                  setState(
                                      () => _concurrentDownloads = count);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.primary
                                        : AppColors.surfaceElevated,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color: sel
                                            ? AppColors.primary
                                            : AppColors.surfaceBorder),
                                  ),
                                  child: Center(
                                    child: Text('${count}x',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: sel
                                              ? AppColors.onPrimary
                                              : AppColors.textPrimary,
                                        )),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Android only ─────────────────────────────────────────────────
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 24),
            _sectionLabel('PERMISSIONS'),
            const SizedBox(height: 8),
            _card(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading:
                        _iconBox(Icons.notifications_active_outlined),
                    title: Text('Download Notifications',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    subtitle: Text(
                        'Show progress in the notification shade',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    trailing: FilledButton(
                      onPressed: () async {
                        final AndroidDownloaderService s;
                        if (_downloaderService is AndroidDownloaderService) {
                          s = _downloaderService;
                        } else {
                          s = AndroidDownloaderService();
                        }
                        final granted =
                            await s.requestNotificationPermission();
                        if (context.mounted) {
                          _showSnackbar(granted
                              ? 'Notifications enabled!'
                              : 'Permission not granted');
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Allow',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.surfaceBorder),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading:
                        _iconBox(Icons.battery_charging_full_outlined),
                    title: Text('Background Downloads',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    subtitle: Text(
                        'Keep downloading when screen is off',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    trailing: FilledButton(
                      onPressed: () async {
                        final AndroidDownloaderService s;
                        if (_downloaderService is AndroidDownloaderService) {
                          s = _downloaderService;
                        } else {
                          s = AndroidDownloaderService();
                        }
                        await s.requestIgnoreBatteryOptimizations();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Allow',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                leading: _iconBox(Icons.system_update_alt_rounded),
                title: Text('Update Downloader Engine',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                subtitle: Text(
                    'Get the latest yt-dlp for faster, more compatible downloads',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                trailing: FilledButton.tonal(
                  onPressed:
                      _isUpdatingEngine ? null : _handleUpdateEngine,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isUpdatingEngine
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                      : const Text('Update',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],

          const SizedBox(height: 40),

          // ── Footer ────────────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.music_note_rounded,
                      color: AppColors.onPrimary, size: 26),
                ),
                const SizedBox(height: 10),
                Text('Infyn DL',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text('Music Player & Downloader',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: child,
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
    );
  }

}
