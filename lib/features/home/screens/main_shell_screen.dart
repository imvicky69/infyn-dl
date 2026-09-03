import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloader/screens/downloader_screen.dart';
import '../../downloader/services/downloader_service.dart';
import '../../library/screens/library_screen.dart';
import '../../settings/screens/settings_screen.dart';

/// Top-level shell screen providing modern bottom tab navigation.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    this.downloaderService,
  });

  final DownloaderService? downloaderService;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DownloaderScreen(
            downloaderService: widget.downloaderService,
            onOpenSettings: () => setState(() => _currentIndex = 2),
            onOpenLibrary: () => setState(() => _currentIndex = 1),
          ),
          LibraryScreen(
            onNavigateToDownloader: () => setState(() => _currentIndex = 0),
          ),
          SettingsScreen(
            downloaderService: widget.downloaderService,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceElevated : AppColors.surface,
          border: const Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.download_outlined,
                  selectedIcon: Icons.download_rounded,
                  label: 'Downloader',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.folder_copy_outlined,
                  selectedIcon: Icons.folder_copy_rounded,
                  label: 'Library',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.tune_outlined,
                  selectedIcon: Icons.tune_rounded,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 20,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
