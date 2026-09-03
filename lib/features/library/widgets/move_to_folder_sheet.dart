import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloader/models/download_item.dart';

/// Modal bottom sheet allowing users to quickly move a song or batch of songs
/// to "Unorganized", an existing playlist folder, or a newly created folder.
class MoveToFolderSheet extends StatefulWidget {
  const MoveToFolderSheet({
    super.key,
    required this.itemsToMove,
    required this.availablePlaylists,
    required this.onMove,
  });

  final List<DownloadItem> itemsToMove;
  final List<String> availablePlaylists;
  final ValueChanged<String?> onMove;

  static Future<void> show({
    required BuildContext context,
    required List<DownloadItem> items,
    required List<String> availablePlaylists,
    required ValueChanged<String?> onMove,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MoveToFolderSheet(
        itemsToMove: items,
        availablePlaylists: availablePlaylists,
        onMove: onMove,
      ),
    );
  }

  @override
  State<MoveToFolderSheet> createState() => _MoveToFolderSheetState();
}

class _MoveToFolderSheetState extends State<MoveToFolderSheet> {
  bool _isCreatingNew = false;
  final TextEditingController _newFolderController = TextEditingController();

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  void _submitNewFolder() {
    final name = _newFolderController.text.trim();
    if (name.isNotEmpty) {
      Navigator.of(context).pop();
      widget.onMove(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.itemsToMove.length;
    final titleText = count == 1
        ? 'Move "${widget.itemsToMove.first.title}"'
        : 'Move $count Selected Items';

    // Current playlist of the items (if all share the same)
    final firstPlaylist = widget.itemsToMove.first.playlistName;
    final allSame = widget.itemsToMove.every(
      (item) => item.playlistName == firstPlaylist,
    );
    final currentPlaylist = allSame ? firstPlaylist : null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: const Icon(Icons.drive_file_move_rounded,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Move to Folder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          titleText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.surfaceBorder),

            // Destinations List
            Flexible(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // 1. Unorganized Option
                    _buildDestinationTile(
                      icon: Icons.inbox_rounded,
                      iconColor: const Color(0xFFD97706),
                      title: 'Unorganized',
                      subtitle: 'Direct Downloads / Uncategorized',
                      isCurrent: currentPlaylist == null ||
                          currentPlaylist.trim().isEmpty,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onMove(null);
                      },
                    ),

                    // 2. Existing Playlists
                    for (final playlist in widget.availablePlaylists)
                      _buildDestinationTile(
                        icon: Icons.folder_rounded,
                        iconColor: AppColors.primary,
                        title: playlist,
                        isCurrent: currentPlaylist != null &&
                            currentPlaylist.trim() == playlist.trim(),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onMove(playlist);
                        },
                      ),

                    const SizedBox(height: 8),

                    // 3. Create New Folder Action
                    if (!_isCreatingNew)
                      InkWell(
                        onTap: () => setState(() => _isCreatingNew = true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.surfaceBorder,
                              style: BorderStyle.solid,
                            ),
                            color: AppColors.surfaceElevated,
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.create_new_folder_rounded,
                                  size: 20, color: AppColors.primary),
                              SizedBox(width: 12),
                              Text(
                                '+ Create New Playlist Folder',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newFolderController,
                                autofocus: true,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                  hintText: 'New folder name...',
                                  hintStyle: TextStyle(
                                      fontSize: 13, color: AppColors.textMuted),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _submitNewFolder(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _submitNewFolder,
                              child: const Text('Move',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isCurrent ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 22, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w600,
                          color: isCurrent
                              ? AppColors.textPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: const Text(
                      'Current',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted),
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
