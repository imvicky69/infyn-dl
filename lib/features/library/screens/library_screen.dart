import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_opener.dart';
import '../../../core/utils/file_resolver.dart';
import '../../downloader/models/download_format.dart';
import '../../downloader/models/download_item.dart';
import '../../downloader/services/download_history_service.dart';
import '../../settings/services/settings_service.dart';
import '../models/library_folder.dart';
import '../widgets/folder_card.dart';
import '../widgets/move_to_folder_sheet.dart';

/// Screen showcasing downloaded media organized by playlist folders,
/// unorganized direct downloads, and separate video folders with rich thumbnail artwork.
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
  String _selectedFilter = 'all'; // 'all', 'playlists', 'video', 'audio'
  String _viewMode = 'folders'; // 'folders' or 'all'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  LibraryFolder? _openedFolder;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedItemIds = {};

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

    // Background self-healing pass for files that might need path resolution
    _healExistingPaths();
  }

  Future<void> _healExistingPaths() async {
    for (final item in _items) {
      if (item.filePath.isNotEmpty) {
        try {
          if (!await File(item.filePath).exists()) {
            await FileResolver.resolveFile(item);
          }
        } catch (_) {}
      }
    }
  }

  List<LibraryFolder> get _folders {
    final Map<String, List<DownloadItem>> playlistGroups = {};
    final List<DownloadItem> unorganizedItems = [];
    final List<DownloadItem> videoItems = [];

    for (final item in _items) {
      if (item.format == DownloadFormat.mp4) {
        videoItems.add(item);
      } else if (item.playlistName != null &&
          item.playlistName!.trim().isNotEmpty) {
        final pName = item.playlistName!.trim();
        playlistGroups.putIfAbsent(pName, () => []).add(item);
      } else {
        unorganizedItems.add(item);
      }
    }

    final result = <LibraryFolder>[];

    // 1. Audio Playlists
    for (final entry in playlistGroups.entries) {
      result.add(LibraryFolder(
        name: entry.key,
        folderType: LibraryFolderType.playlist,
        items: entry.value,
      ));
    }

    // 2. Unorganized (Direct Downloads)
    if (unorganizedItems.isNotEmpty) {
      result.add(LibraryFolder(
        name: 'Unorganized',
        folderType: LibraryFolderType.unorganized,
        items: unorganizedItems,
      ));
    }

    // 3. Videos
    if (videoItems.isNotEmpty) {
      result.add(LibraryFolder(
        name: 'Videos',
        folderType: LibraryFolderType.videos,
        items: videoItems,
      ));
    }

    // Filter folders based on selectedFilter
    return result.where((folder) {
      if (_selectedFilter == 'playlists' && !folder.isPlaylist) return false;
      if (_selectedFilter == 'video' && !folder.isVideos) return false;
      if (_selectedFilter == 'audio' && folder.isVideos) return false;

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final folderMatches =
            folder.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final itemMatches = folder.items.any((item) =>
            item.title.toLowerCase().contains(_searchQuery.toLowerCase()));
        if (!folderMatches && !itemMatches) return false;
      }
      return true;
    }).toList();
  }

  List<DownloadItem> get _filteredAllItems {
    return _items.where((item) {
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
    final resolvedPath = await FileResolver.resolveFile(item);
    if (resolvedPath == null) {
      _showSnackbar(
        'File no longer exists at: ${item.filePath}',
        isError: true,
      );
      return;
    }

    final success = await FileOpener.open(resolvedPath);
    if (!success) {
      _showSnackbar('Could not open file: ${item.title}', isError: true);
    }
  }

  Future<void> _showInExplorer(DownloadItem item) async {
    final resolvedPath = await FileResolver.resolveFile(item);
    final target = resolvedPath ?? item.filePath;
    if (target.isEmpty) return;

    final dir = Directory(p.dirname(target));
    if (await dir.exists()) {
      await FileOpener.open(dir.path);
    } else {
      final baseDir = await SettingsService.instance.resolveDownloadDirectory();
      await FileOpener.open(baseDir);
    }
  }

  Future<void> _openFolderInExplorer(LibraryFolder folder) async {
    try {
      final baseDir = await SettingsService.instance.resolveDownloadDirectory();
      String targetDir;
      if (folder.isVideos) {
        targetDir = p.join(baseDir, 'Videos');
      } else if (folder.isUnorganized) {
        targetDir = baseDir;
      } else {
        targetDir = p.join(baseDir, folder.name);
      }

      final dir = Directory(targetDir);
      if (await dir.exists()) {
        await FileOpener.open(targetDir);
      } else {
        await FileOpener.open(baseDir);
      }
    } catch (_) {}
  }

  void _openMoveSheet(List<DownloadItem> items) {
    final playlists =
        _folders.where((f) => f.isPlaylist).map((f) => f.name).toList();

    MoveToFolderSheet.show(
      context: context,
      items: items,
      availablePlaylists: playlists,
      onMove: (targetPlaylist) async {
        await DownloadHistoryService.instance.moveItemsToPlaylist(
          itemIds: items.map((i) => i.id).toList(),
          targetPlaylistName: targetPlaylist,
        );
        setState(() {
          _isMultiSelectMode = false;
          _selectedItemIds.clear();
        });
        await _loadHistory();
        _showSnackbar(
          targetPlaylist == null
              ? 'Moved ${items.length} ${items.length == 1 ? 'item' : 'items'} to Unorganized'
              : 'Moved ${items.length} ${items.length == 1 ? 'item' : 'items'} to "$targetPlaylist"',
        );
      },
    );
  }

  Future<void> _renameFolderDialog(LibraryFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Playlist Folder',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != folder.name) {
      await DownloadHistoryService.instance.renamePlaylist(
        oldName: folder.name,
        newName: newName,
      );
      if (_openedFolder?.name == folder.name) {
        _openedFolder = LibraryFolder(
          name: newName,
          folderType: folder.folderType,
          items: folder.items,
        );
      }
      await _loadHistory();
      _showSnackbar('Renamed folder to "$newName"');
    }
  }

  Future<void> _deleteFolderDialog(LibraryFolder folder) async {
    final shouldDeleteFiles = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${folder.name}"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          'Remove all ${folder.count} items in "${folder.name}" from your library?\n\nDo you also want to delete the physical files from disk?',
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Files & Entries'),
          ),
        ],
      ),
    );

    if (shouldDeleteFiles != null) {
      await DownloadHistoryService.instance.deletePlaylist(
        playlistName: folder.name,
        deletePhysicalFiles: shouldDeleteFiles,
      );
      if (_openedFolder?.name == folder.name) {
        setState(() => _openedFolder = null);
      }
      await _loadHistory();
      _showSnackbar('Folder removed');
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
      setState(() => _openedFolder = null);
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
    if (_openedFolder != null) {
      return _buildFolderDetailScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Downloads Library',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          // View Switcher (Folders vs Flat List)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewToggleBtn(
                  icon: Icons.folder_copy_rounded,
                  mode: 'folders',
                  tooltip: 'Folders View',
                ),
                _buildViewToggleBtn(
                  icon: Icons.view_list_rounded,
                  mode: 'all',
                  tooltip: 'All Files View',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
                // Search & Filter Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Search Bar
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
                            hintText: _viewMode == 'folders'
                                ? 'Search folders or tracks...'
                                : 'Search downloads...',
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

                      // Filter Chips
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

                // Main Content
                Expanded(
                  child: _viewMode == 'folders'
                      ? _buildFoldersView()
                      : _buildAllFilesView(),
                ),
              ],
            ),
    );
  }

  Widget _buildViewToggleBtn({
    required IconData icon,
    required String mode,
    required String tooltip,
  }) {
    final isSelected = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _viewMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildFoldersView() {
    final folders = _folders;
    if (folders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: folders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final folder = folders[index];
          return FolderCard(
            folder: folder,
            onTap: () => setState(() => _openedFolder = folder),
            onItemDropped: (droppedItem) async {
              final target = folder.isUnorganized ? null : folder.name;
              await DownloadHistoryService.instance.moveItemsToPlaylist(
                itemIds: [droppedItem.id],
                targetPlaylistName: target,
              );
              await _loadHistory();
              _showSnackbar(
                target == null
                    ? 'Moved to Unorganized'
                    : 'Moved to "${folder.name}"',
              );
            },
            onOpenInExplorer:
                _isDesktop ? () => _openFolderInExplorer(folder) : null,
            onRename:
                folder.isPlaylist ? () => _renameFolderDialog(folder) : null,
            onDelete: () => _deleteFolderDialog(folder),
          );
        },
      ),
    );
  }

  Widget _buildAllFilesView() {
    final filtered = _filteredAllItems;
    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildDownloadCard(item);
        },
      ),
    );
  }

  Widget _buildFolderDetailScreen() {
    final folder = _openedFolder!;
    // Find updated folder data
    final current = _folders.firstWhere(
      (f) => f.name == folder.name && f.folderType == folder.folderType,
      orElse: () => folder,
    );

    final items = current.items.where((item) {
      if (_searchQuery.isNotEmpty) {
        return item.title.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () {
            setState(() {
              _openedFolder = null;
              _isMultiSelectMode = false;
              _selectedItemIds.clear();
            });
          },
        ),
        title: Row(
          children: [
            Icon(
              current.isVideos
                  ? Icons.movie_rounded
                  : (current.isUnorganized
                      ? Icons.inbox_rounded
                      : Icons.folder_rounded),
              size: 20,
              color: current.isUnorganized
                  ? const Color(0xFFD97706)
                  : (current.isVideos
                      ? const Color(0xFF2563EB)
                      : AppColors.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${current.count} ${current.count == 1 ? 'track' : 'tracks'}${current.formattedTotalSize.isNotEmpty ? ' • ${current.formattedTotalSize}' : ''}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isMultiSelectMode
                  ? Icons.check_circle_rounded
                  : Icons.checklist_rounded,
              color: _isMultiSelectMode
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            tooltip: 'Select multiple items to move',
            onPressed: () {
              setState(() {
                _isMultiSelectMode = !_isMultiSelectMode;
                _selectedItemIds.clear();
              });
            },
          ),
          if (_isDesktop)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded,
                  color: AppColors.textSecondary),
              tooltip: 'Open in Explorer',
              onPressed: () => _openFolderInExplorer(current),
            ),
          if (current.isPlaylist)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'rename') _renameFolderDialog(current);
                if (val == 'delete') _deleteFolderDialog(current);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Text('Rename Playlist', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Delete Playlist...',
                          style:
                              TextStyle(fontSize: 13, color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search in folder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search in "${current.name}"...',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: AppColors.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.surfaceBorder),

          // Items inside folder
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No matches found'
                          : 'No items in this folder',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildDownloadCard(item);
                    },
                  ),
          ),

          // Multi-Select Floating Action Bar
          if (_isMultiSelectMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Text(
                      '${_selectedItemIds.length} selected',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedItemIds.length == items.length) {
                            _selectedItemIds.clear();
                          } else {
                            _selectedItemIds.addAll(items.map((e) => e.id));
                          }
                        });
                      },
                      child: Text(
                        _selectedItemIds.length == items.length
                            ? 'Deselect All'
                            : 'Select All',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _selectedItemIds.isEmpty
                          ? null
                          : () {
                              final selectedItems = items
                                  .where((i) => _selectedItemIds.contains(i.id))
                                  .toList();
                              _openMoveSheet(selectedItems);
                            },
                      icon: const Icon(Icons.drive_file_move_rounded, size: 16),
                      label: const Text('Move',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
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
    final isSelected = _selectedItemIds.contains(item.id);
    final thumbUrl = item.effectiveThumbnailUrl;

    final cardContent = Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (_isMultiSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedItemIds.remove(item.id);
              } else {
                _selectedItemIds.add(item.id);
              }
            });
          } else {
            _openMediaFile(item);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox if in multi-select mode
              if (_isMultiSelectMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  onChanged: (_) {
                    setState(() {
                      if (isSelected) {
                        _selectedItemIds.remove(item.id);
                      } else {
                        _selectedItemIds.add(item.id);
                      }
                    });
                  },
                ),
                const SizedBox(width: 6),
              ],

              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 54,
                  height: 54,
                  color: AppColors.surfaceElevated,
                  child: thumbUrl != null && thumbUrl.isNotEmpty
                      ? Image.network(
                          thumbUrl,
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
                                : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isAudio
                                  ? AppColors.primary.withValues(alpha: 0.3)
                                  : const Color(0xFF93C5FD),
                            ),
                          ),
                          child: Text(
                            item.format.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isAudio
                                  ? AppColors.primary
                                  : const Color(0xFF1E40AF),
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
                  } else if (action == 'move') {
                    _openMoveSheet([item]);
                  } else if (action == 'explorer') {
                    _showInExplorer(item);
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
                  const PopupMenuItem(
                    value: 'move',
                    child: Row(
                      children: [
                        Icon(Icons.drive_file_move_rounded,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Move to Folder...',
                            style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  if (_isDesktop)
                    const PopupMenuItem(
                      value: 'explorer',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new_rounded,
                              size: 18, color: AppColors.textSecondary),
                          SizedBox(width: 8),
                          Text('Show in Explorer',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.error),
                        SizedBox(width: 8),
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

    // If multi-select is off, wrap with LongPressDraggable for drag-and-drop moving to folder cards
    if (!_isMultiSelectMode) {
      return LongPressDraggable<DownloadItem>(
        data: item,
        feedback: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.drive_file_move_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        child: cardContent,
      );
    }

    return cardContent;
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
              'Downloaded media will be organized here into playlist folders, unorganized downloads, and videos.',
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
