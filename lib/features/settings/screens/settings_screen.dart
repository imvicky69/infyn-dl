import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
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
          // Section: Download Storage Location
          const Text(
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
                      child: const Icon(Icons.folder_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
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
                    style: const TextStyle(
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
                          foregroundColor: Colors.white,
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
                          side:
                              const BorderSide(color: AppColors.surfaceBorder),
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
          const Text(
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
                  title: const Text(
                    'Auto-Skip Already Downloaded Files',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: const Text(
                    'Instantly skips songs or videos that already exist on disk or in history',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onChanged: (val) async {
                    await SettingsService.instance.setAutoSkipDuplicates(val);
                    setState(() => _autoSkip = val);
                  },
                ),
                const Divider(
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
                  title: const Text(
                    'Create Playlist Subfolder',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: const Text(
                    'Groups batch playlist downloads into a dedicated folder named after the playlist',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onChanged: (val) async {
                    await SettingsService.instance.setPlaylistSubfolder(val);
                    setState(() => _playlistSubfolder = val);
                  },
                ),
                const Divider(
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
                          const Text(
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
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
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
                                            ? Colors.white
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
            const Text(
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
                    leading: const Icon(Icons.notifications_active_outlined,
                        color: AppColors.primary),
                    title: const Text(
                      'Live Download Notifications',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
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
                        foregroundColor: Colors.white,
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
                  const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.surfaceBorder),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: const Icon(Icons.battery_charging_full_outlined,
                        color: AppColors.primary),
                    title: const Text(
                      'Unrestricted Background Downloading',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
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
                        foregroundColor: Colors.white,
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
          const Text(
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
                ? const Center(
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
                      const Divider(height: 16, color: AppColors.surfaceBorder),
                      _buildDiagnosticRow(
                        'Audio Processor',
                        'FFmpeg 320kbps Encoder',
                        Icons.check_circle_rounded,
                        AppColors.success,
                      ),
                      const Divider(height: 16, color: AppColors.surfaceBorder),
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
                        const Divider(height: 16, color: AppColors.surfaceBorder),
                        Row(
                          children: [
                            const Icon(Icons.system_update_alt_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 12),
                            const Expanded(
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
                                  ? const SizedBox(
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
                const Text(
                  'Infyn DL • v1.0.0',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                const Text(
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
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
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
}
