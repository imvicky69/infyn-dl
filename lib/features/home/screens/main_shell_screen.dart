import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloader/screens/downloader_screen.dart';
import '../../downloader/services/downloader_service.dart';
import '../../library/screens/library_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../tools/screens/tools_screen.dart';

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
            onOpenSettings: () => setState(() => _currentIndex = 3),
            onOpenLibrary: () => setState(() => _currentIndex = 1),
          ),
          LibraryScreen(
            downloaderService: widget.downloaderService,
            onNavigateToDownloader: () => setState(() => _currentIndex = 0),
          ),
          const ToolsScreen(),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  icon: Icons.handyman_outlined,
                  selectedIcon: Icons.handyman_rounded,
                  label: 'Tools',
                ),
                _buildNavItem(
                  index: 3,
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
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? selectedIcon : icon,
                size: 22,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
