import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloader/services/downloader_service.dart';
import '../../library/screens/library_shell_screen.dart';
import '../../library/screens/music_library_screen.dart';
import '../../player/screens/desktop_player_screen.dart';
import '../../player/services/audio_player_service.dart';
import '../../player/widgets/desktop_player_bar.dart';
import '../../player/widgets/mini_player.dart';
import '../../search/screens/search_screen.dart';
import '../../settings/screens/settings_screen.dart';

/// Top-level shell screen — music-first, 3 tabs: Music | Library | Settings.
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
  int _currentIndex = 0; // 0=Music, 1=Search, 2=Library, 3=Settings
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
  // DESKTOP LAYOUT
  // ==========================================
  Widget _buildDesktopLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA),
      body: Row(
        children: [
          _buildDesktopSidebar(context, isDark),
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
                        MusicLibraryScreen(
                          onNavigateToDownloader: () =>
                              setState(() => _currentIndex = 2),
                        ),
                        const SearchScreen(),
                        LibraryShellScreen(
                          downloaderService: widget.downloaderService,
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
              setState(() => _isDesktopPlayerOpen = !_isDesktopPlayerOpen);
            },
          );
        },
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, bool isDark) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : const Color(0xFFFFFFFF),
        border: Border(
          right: BorderSide(color: AppColors.surfaceBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  child: Icon(Icons.music_note_rounded,
                      color: AppColors.onPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Infyn DL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          )),
                      Text('Music Player',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildSidebarNavItem(
            index: 0,
            icon: Icons.music_note_outlined,
            selectedIcon: Icons.music_note_rounded,
            label: 'Music',
          ),
          _buildSidebarNavItem(
            index: 1,
            icon: Icons.search_outlined,
            selectedIcon: Icons.search_rounded,
            label: 'Search',
          ),
          _buildSidebarNavItem(
            index: 2,
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder_rounded,
            label: 'Library',
          ),
          _buildSidebarNavItem(
            index: 3,
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: 'Settings',
          ),
          const Spacer(),
          // Now Playing shortcut
          ListenableBuilder(
            listenable: AudioPlayerService.instance,
            builder: (context, _) {
              final track = AudioPlayerService.instance.currentTrack;
              if (track == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: InkWell(
                  onTap: () => setState(
                      () => _isDesktopPlayerOpen = !_isDesktopPlayerOpen),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isDesktopPlayerOpen
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _isDesktopPlayerOpen
                              ? AppColors.primary
                              : AppColors.surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_fill_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isDesktopPlayerOpen
                                ? 'Close Now Playing'
                                : 'Now Playing',
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
        onTap: () => setState(() {
          _currentIndex = index;
          _isDesktopPlayerOpen = false;
        }),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
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
  // MOBILE LAYOUT — Music first, 4 tabs
  // ==========================================
  Widget _buildMobileLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Main tab content
          IndexedStack(
            index: _currentIndex,
            children: [
              // 0 — Music
              MusicLibraryScreen(
                onNavigateToDownloader: () => setState(() => _currentIndex = 2),
              ),
              // 1 — Search
              const SearchScreen(),
              // 2 — Library
              LibraryShellScreen(
                downloaderService: widget.downloaderService,
              ),
              // 3 — Settings
              SettingsScreen(
                downloaderService: widget.downloaderService,
              ),
            ],
          ),

          // Persistent mini-player above bottom nav
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
                  icon: Icons.music_note_outlined,
                  selectedIcon: Icons.music_note_rounded,
                  label: 'Music',
                ),
                _buildMobileNavItem(
                  index: 1,
                  icon: Icons.search_outlined,
                  selectedIcon: Icons.search_rounded,
                  label: 'Search',
                ),
                _buildMobileNavItem(
                  index: 2,
                  icon: Icons.folder_outlined,
                  selectedIcon: Icons.folder_rounded,
                  label: 'Library',
                ),
                _buildMobileNavItem(
                  index: 3,
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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
