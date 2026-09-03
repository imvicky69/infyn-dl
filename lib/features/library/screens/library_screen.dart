import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_opener.dart';
import '../../downloader/models/download_format.dart';
import '../../downloader/models/download_item.dart';
import '../../downloader/services/download_history_service.dart';

/// Screen showcasing the cache/history of all downloaded media files.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    this.onNavigateToDownloader,
  });

  final VoidCallback? onNavigateToDownloader;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<DownloadItem> _items = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'video', 'audio'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await DownloadHistoryService.instance.getHistory();
    if (mounted) {
      setState(() {
        _items = history;
        _isLoading = false;
      });
    }
  }

  List<DownloadItem> get _filteredItems {
    return _items.where((item) {
      // Format / Playlist filter
      if (_selectedFilter == 'video' && item.format != DownloadFormat.mp4) {
        return false;
      }
      if (_selectedFilter == 'audio' && item.format != DownloadFormat.mp3) {
        return false;
      }
      if (_selectedFilter == 'playlists' &&
          (item.playlistName == null || item.playlistName!.isEmpty)) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final titleMatches =
            item.title.toLowerCase().contains(_searchQuery.toLowerCase());
        final playlistMatches = item.playlistName
                ?.toLowerCase()
                .contains(_searchQuery.toLowerCase()) ??
            false;
        if (!titleMatches && !playlistMatches) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _openMediaFile(DownloadItem item) async {
    if (item.filePath.isEmpty) {
      _showSnackbar('File path is unavailable', isError: true);
      return;
    }

    final file = File(item.filePath);
    if (!await file.exists()) {
      _showSnackbar('File no longer exists at: ${item.filePath}',
          isError: true);
      return;
    }

    final success = await FileOpener.open(item.filePath);
    if (!success) {
      _showSnackbar('Could not open file: ${item.title}', isError: true);
    }
  }

  Future<void> _deleteItem(DownloadItem item) async {
    final shouldDeleteFile = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Download',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          'Remove "${item.title}" from downloads library?\n\nDo you also want to delete the file from disk?',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Remove from Library Only'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete File & Entry'),
          ),
        ],
      ),
    );

    if (shouldDeleteFile != null) {
      await DownloadHistoryService.instance.removeDownload(
        item.id,
        deletePhysicalFile: shouldDeleteFile,
      );
      await _loadHistory();
      _showSnackbar('Download removed');
    }
  }

  Future<void> _clearAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will clear all entries from your downloads cache. Files on disk will NOT be deleted.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DownloadHistoryService.instance.clearHistory();
      await _loadHistory();
      _showSnackbar('History cleared');
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

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Row(
          children: [
            Text(
              'Downloads Library',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: AppColors.textMuted),
              tooltip: 'Clear history',
              onPressed: _clearAllHistory,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : Column(
              children: [
                // Search & Filter header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Search bar
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val.trim()),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search downloads...',
                            hintStyle: const TextStyle(
                                fontSize: 13, color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.search_rounded,
                                size: 18, color: AppColors.textMuted),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'all', _items.length),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'Playlists',
                              'playlists',
                              _items
                                  .where((i) =>
                                      i.playlistName != null &&
                                      i.playlistName!.isNotEmpty)
                                  .length,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'Videos',
                              'video',
                              _items
                                  .where((i) => i.format == DownloadFormat.mp4)
                                  .length,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'Audio',
                              'audio',
                              _items
                                  .where((i) => i.format == DownloadFormat.mp3)
                                  .length,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: AppColors.surfaceBorder),

                // Items list or empty state
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadHistory,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _buildDownloadCard(item);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.textPrimary : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white70 : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadCard(DownloadItem item) {
    final isAudio = item.format == DownloadFormat.mp3;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: InkWell(
        onTap: () => _openMediaFile(item),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail or Format Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 54,
                  height: 54,
                  color: AppColors.surfaceElevated,
                  child: item.thumbnailUrl != null &&
                          item.thumbnailUrl!.isNotEmpty
                      ? Image.network(
                          item.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            isAudio
                                ? Icons.music_note_rounded
                                : Icons.videocam_rounded,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        )
                      : Icon(
                          isAudio
                              ? Icons.music_note_rounded
                              : Icons.videocam_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Media details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Format Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAudio
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isAudio
                                  ? AppColors.primary.withValues(alpha: 0.3)
                                  : AppColors.surfaceBorder,
                            ),
                          ),
                          child: Text(
                            item.format.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isAudio
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (item.quality.isNotEmpty) ...[
                          Text(
                            item.quality,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                          const Text(' • ',
                              style: TextStyle(color: AppColors.textMuted)),
                        ],
                        if (item.formattedFileSize.isNotEmpty) ...[
                          Text(
                            item.formattedFileSize,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                          const Text(' • ',
                              style: TextStyle(color: AppColors.textMuted)),
                        ],
                        Text(
                          _formatTimestamp(item.timestamp),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    if (item.playlistName != null &&
                        item.playlistName!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.playlist_play_rounded,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              item.playlistName!,
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Action menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    size: 18, color: AppColors.textMuted),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (action) {
                  if (action == 'open') {
                    _openMediaFile(item);
                  } else if (action == 'delete') {
                    _deleteItem(item);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Open File', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('Delete...',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 36,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Downloads Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Downloaded videos and audio will be saved and cached here for quick offline access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            if (widget.onNavigateToDownloader != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: widget.onNavigateToDownloader,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Go to Downloader',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
