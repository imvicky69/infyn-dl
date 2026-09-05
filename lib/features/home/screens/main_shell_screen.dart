import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloader/screens/downloader_screen.dart';
import '../../downloader/services/downloader_service.dart';
import '../../library/screens/library_screen.dart';
import '../../library/screens/music_library_screen.dart';
import '../../player/screens/desktop_player_screen.dart';
import '../../player/services/audio_player_service.dart';
import '../../player/widgets/desktop_player_bar.dart';
import '../../player/widgets/mini_player.dart';
import '../../settings/screens/settings_screen.dart';

/// Top-level shell screen providing responsive navigation and persistent player integration.
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
  bool _isDesktopPlayerOpen = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useWideLayout = screenWidth >= 800;

    if (useWideLayout) {
      return _buildDesktopLayout(context);
    } else {
      return _buildMobileLayout(context);
    }
  }

  // ==========================================
  // DESKTOP / WINDOWS LAYOUT (YouTube Music)
  // ==========================================
  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA),
      body: Row(
        children: [
          // Left Navigation Sidebar
          _buildDesktopSidebar(context, isDark),

          // Main Content View
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isDesktopPlayerOpen
                  ? DesktopPlayerScreen(
                      onClose: () =>
                          setState(() => _isDesktopPlayerOpen = false),
                    )
                  : IndexedStack(
                      key: const ValueKey('screens_stack'),
                      index: _currentIndex,
                      children: [
                        DownloaderScreen(
                          downloaderService: widget.downloaderService,
                          onOpenSettings: () =>
                              setState(() => _currentIndex = 3),
                          onOpenLibrary: () =>
                              setState(() => _currentIndex = 1),
                        ),
                        MusicLibraryScreen(
                          onNavigateToDownloader: () =>
                              setState(() => _currentIndex = 0),
                        ),
                        LibraryScreen(
                          downloaderService: widget.downloaderService,
                          onNavigateToDownloader: () =>
                              setState(() => _currentIndex = 0),
                        ),
                        SettingsScreen(
                          downloaderService: widget.downloaderService,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: AudioPlayerService.instance,
        builder: (context, _) {
          final hasTrack = AudioPlayerService.instance.currentTrack != null;
          if (!hasTrack) return const SizedBox.shrink();

          return DesktopPlayerBar(
            isPlayerScreenOpen: _isDesktopPlayerOpen,
            onTogglePlayerScreen: () {
              setState(() {
                _isDesktopPlayerOpen = !_isDesktopPlayerOpen;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, bool isDark) {
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : const Color(0xFFFFFFFF),
        border: Border(
          right: BorderSide(
            color: AppColors.surfaceBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: AppColors.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Infyn DL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Music & Downloader',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Navigation Links
          _buildSidebarNavItem(
            index: 0,
            icon: Icons.download_outlined,
            selectedIcon: Icons.download_rounded,
            label: 'Downloader',
          ),
          _buildSidebarNavItem(
            index: 1,
            icon: Icons.music_note_outlined,
            selectedIcon: Icons.music_note_rounded,
            label: 'Music',
          ),
          _buildSidebarNavItem(
            index: 2,
            icon: Icons.folder_copy_outlined,
            selectedIcon: Icons.folder_copy_rounded,
            label: 'Library',
          ),
          _buildSidebarNavItem(
            index: 3,
            icon: Icons.tune_outlined,
            selectedIcon: Icons.tune_rounded,
            label: 'Settings',
          ),

          const Spacer(),

          // Now Playing Shortcut if active
          ListenableBuilder(
            listenable: AudioPlayerService.instance,
            builder: (context, _) {
              final track = AudioPlayerService.instance.currentTrack;
              if (track == null) return const SizedBox.shrink();

              final isSelected = _isDesktopPlayerOpen;

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isDesktopPlayerOpen = !_isDesktopPlayerOpen;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.play_circle_fill_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isSelected
                                ? 'Close Now Playing'
                                : 'Now Playing View',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final isSelected = !_isDesktopPlayerOpen && _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
            _isDesktopPlayerOpen = false;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MOBILE / PHONE LAYOUT (YouTube Music)
  // ==========================================
  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Main tab content
          IndexedStack(
            index: _currentIndex,
            children: [
              DownloaderScreen(
                downloaderService: widget.downloaderService,
                onOpenSettings: () => setState(() => _currentIndex = 3),
                onOpenLibrary: () => setState(() => _currentIndex = 1),
              ),
              MusicLibraryScreen(
                onNavigateToDownloader: () => setState(() => _currentIndex = 0),
              ),
              LibraryScreen(
                downloaderService: widget.downloaderService,
                onNavigateToDownloader: () => setState(() => _currentIndex = 0),
              ),
              SettingsScreen(
                downloaderService: widget.downloaderService,
              ),
            ],
          ),

          // Persistent Mini-Player floating above bottom navigation bar
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceElevated : AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMobileNavItem(
                  index: 0,
                  icon: Icons.download_outlined,
                  selectedIcon: Icons.download_rounded,
                  label: 'Downloader',
                ),
                _buildMobileNavItem(
                  index: 1,
                  icon: Icons.music_note_outlined,
                  selectedIcon: Icons.music_note_rounded,
                  label: 'Music',
                ),
                _buildMobileNavItem(
                  index: 2,
                  icon: Icons.folder_copy_outlined,
                  selectedIcon: Icons.folder_copy_rounded,
                  label: 'Library',
                ),
                _buildMobileNavItem(
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

  Widget _buildMobileNavItem({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? selectedIcon : icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
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
