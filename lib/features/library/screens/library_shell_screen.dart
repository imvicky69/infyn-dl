import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloader/screens/downloader_screen.dart';
import '../../downloader/services/downloader_service.dart';
import 'library_screen.dart';

/// Library tab shell — contains two sub-tabs:
/// "My Music" (download history / folders) and "Download" (the downloader).
class LibraryShellScreen extends StatefulWidget {
  const LibraryShellScreen({
    super.key,
    this.downloaderService,
  });

  final DownloaderService? downloaderService;

  @override
  State<LibraryShellScreen> createState() => _LibraryShellScreenState();
}

class _LibraryShellScreenState extends State<LibraryShellScreen> {
  int _tab = 0; // 0 = My Music, 1 = Download

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Sub-tab pill bar ────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          _TabPill(
                            label: 'My Music',
                            icon: Icons.folder_rounded,
                            selected: _tab == 0,
                            onTap: () => setState(() => _tab = 0),
                          ),
                          _TabPill(
                            label: 'Download',
                            icon: Icons.download_rounded,
                            selected: _tab == 1,
                            onTap: () => setState(() => _tab = 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                LibraryScreen(
                  downloaderService: widget.downloaderService,
                  onNavigateToDownloader: () => setState(() => _tab = 1),
                ),
                DownloaderScreen(
                  downloaderService: widget.downloaderService,
                  onOpenSettings: null, // handled by top-level shell
                  onOpenLibrary: () => setState(() => _tab = 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? AppColors.onPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
