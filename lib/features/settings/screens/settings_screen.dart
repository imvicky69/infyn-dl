import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloader/services/android_downloader_service.dart';
import '../../downloader/services/downloader_service.dart';
import '../../downloader/services/windows_downloader_service.dart';
import '../services/settings_service.dart';

/// Screen allowing configuration of download destination directory and app preferences.
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
  Map<String, String?> _backendInfo = {};
  bool _isLoadingBackend = true;
  bool _isUpdatingEngine = false;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _downloaderService = widget.downloaderService ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? AndroidDownloaderService()
            : WindowsDownloaderService());
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await SettingsService.instance.init();
    final dir = await SettingsService.instance.resolveDownloadDirectory();
    final backend = await _downloaderService.getBackendInfo();

    if (mounted) {
      setState(() {
        _currentDownloadDir = dir;
        _autoSkip = SettingsService.instance.autoSkipDuplicates;
        _playlistSubfolder = SettingsService.instance.playlistSubfolder;
        _concurrentDownloads = SettingsService.instance.concurrentDownloads;
        _backendInfo = backend;
        _themeMode = SettingsService.instance.themeMode;
        _isLoadingBackend = false;
      });
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
      if (mounted) {
        _showSnackbar('Update failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingEngine = false);
      }
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
          setState(() {
            _currentDownloadDir = resolved;
          });
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
      setState(() {
        _currentDownloadDir = resolved;
      });
      _showSnackbar('Reset to default download folder');
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
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
          // Section: Appearance & Dark Mode
          Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _themeMode == ThemeMode.dark ||
                          (_themeMode == ThemeMode.system && isDark)
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(
                'Theme Mode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                _themeMode == ThemeMode.dark
                    ? 'Obsidian Dark'
                    : (_themeMode == ThemeMode.light
                        ? 'Clean Light'
                        : 'System Default'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded, size: 16),
                    tooltip: 'Light',
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_rounded, size: 16),
                    tooltip: 'System',
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded, size: 16),
                    tooltip: 'Dark',
                  ),
                ],
                selected: {_themeMode},
                onSelectionChanged: (newSelection) async {
                  final mode = newSelection.first;
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

          // Section: Download Storage Location
          Text(
            'DOWNLOAD LOCATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.folder_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Save Destination',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                          Text(
                            'Where completed videos and music files are saved',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Current path badge
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Text(
                    _currentDownloadDir,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Buttons: Change Folder / Reset
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
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon:
                            const Icon(Icons.drive_file_move_rounded, size: 16),
                        label: const Text('Change Folder',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (SettingsService.instance.customDownloadPath != null)
                      OutlinedButton(
                        onPressed: _resetDefaultDirectory,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.surfaceBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        child: const Text('Reset',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Download Preferences
          Text(
            'DOWNLOAD PREFERENCES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              children: [
                // Auto-skip duplicates toggle
                SwitchListTile(
                  value: _autoSkip,
                  activeThumbColor: AppColors.primary,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    'Auto-Skip Already Downloaded Files',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Instantly skips songs or videos that already exist on disk or in history',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onChanged: (val) async {
                    await SettingsService.instance.setAutoSkipDuplicates(val);
                    setState(() => _autoSkip = val);
                  },
                ),
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.surfaceBorder),

                // Playlist subfolder toggle
                SwitchListTile(
                  value: _playlistSubfolder,
                  activeThumbColor: AppColors.primary,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    'Create Playlist Subfolder',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Groups batch playlist downloads into a dedicated folder named after the playlist',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onChanged: (val) async {
                    await SettingsService.instance.setPlaylistSubfolder(val);
                    setState(() => _playlistSubfolder = val);
                  },
                ),
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.surfaceBorder),

                // Parallel Downloads Speed
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Parallel Playlist Downloads',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_concurrentDownloads}x Speed',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Downloads multiple tracks simultaneously to drastically accelerate batch playlists.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [1, 2, 3, 4, 5].map((count) {
                          final isSelected = _concurrentDownloads == count;
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () async {
                                  await SettingsService.instance
                                      .setConcurrentDownloads(count);
                                  setState(() => _concurrentDownloads = count);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.surfaceBorder,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${count}x',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppColors.onPrimary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
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

          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 24),
            Text(
              'BACKGROUND DOWNLOADS & PERMISSIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Icon(Icons.notifications_active_outlined,
                        color: AppColors.primary),
                    title: Text(
                      'Live Download Notifications',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      'Shows live ETA, download speed, and progress in your notification shade',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        final service = _downloaderService;
                        final s = service is AndroidDownloaderService
                            ? service
                            : AndroidDownloaderService();
                        final granted = await s.requestNotificationPermission();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(granted
                                  ? 'Notifications enabled!'
                                  : 'Notification permission not granted'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Grant',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.surfaceBorder),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Icon(Icons.battery_charging_full_outlined,
                        color: AppColors.primary),
                    title: Text(
                      'Unrestricted Background Downloading',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      'Prevents Android battery saver from pausing downloads when app is closed or screen is off',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        final service = _downloaderService;
                        final s = service is AndroidDownloaderService
                            ? service
                            : AndroidDownloaderService();
                        await s.requestIgnoreBatteryOptimizations();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Configure',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Section: Diagnostics & Engine Info
          Text(
            'LOCAL ENGINE STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: _isLoadingBackend
                ? Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : Column(
                    children: [
                      _buildDiagnosticRow(
                        'Downloader Core',
                        _backendInfo['ytDlpPath'] != null
                            ? 'yt-dlp (${_backendInfo['ytDlpPath']!.split(Platform.pathSeparator).last})'
                            : 'yt-dlp Native Engine',
                        Icons.check_circle_rounded,
                        AppColors.success,
                      ),
                      Divider(height: 16, color: AppColors.surfaceBorder),
                      _buildDiagnosticRow(
                        'Audio Processor',
                        'FFmpeg 320kbps Encoder',
                        Icons.check_circle_rounded,
                        AppColors.success,
                      ),
                      Divider(height: 16, color: AppColors.surfaceBorder),
                      _buildDiagnosticRow(
                        'Architecture',
                        defaultTargetPlatform == TargetPlatform.android
                            ? 'Android Scoped Storage & C++ JNI'
                            : 'Windows x64 Native Process',
                        Icons.verified_rounded,
                        AppColors.primary,
                      ),
                      if (!kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.android) ...[
                        Divider(height: 16, color: AppColors.surfaceBorder),
                        Row(
                          children: [
                            Icon(Icons.system_update_alt_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Update yt-dlp Core',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Downloads the latest yt-dlp release on device',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: _isUpdatingEngine
                                  ? null
                                  : _handleUpdateEngine,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isUpdatingEngine
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : const Text(
                                      'Check Update',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // Section: Infyn Suite & Web Utilities Overview
          Text(
            'INFYN WEB UTILITIES SUITE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.handyman_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Infyn Browser Tools Suite',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Free in-browser document & image tools',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Access Infyn\'s complete web-based tool suite directly in your browser. Includes PDF tools (PDF to Image, Compress, Merge, Split) and Image converters (WebP, PNG, JPG, Resizer, Optimizer) — processed locally in your browser with zero server uploads.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildToolChip('PDF to Image'),
                    _buildToolChip('Compress PDF'),
                    _buildToolChip('Merge PDF'),
                    _buildToolChip('Image to WebP'),
                    _buildToolChip('Image Resizer'),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openUrl('https://infyn.software'),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: const Text(
                      'Launch Infyn Tools (infyn.software)',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Branding footer
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/logo.png', width: 44, height: 44),
                ),
                const SizedBox(height: 8),
                Text(
                  'Infyn DL • v1.0.0',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Zero-Backend Offline YouTube & Music Downloader',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(
      String title, String subtitle, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text(subtitle,
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'ACTIVE',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.success),
          ),
        ),
      ],
    );
  }

  Widget _buildToolChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackbar('Could not launch: $url', isError: true);
      }
    } catch (e) {
      _showSnackbar('Error opening link: $e', isError: true);
    }
  }
}
