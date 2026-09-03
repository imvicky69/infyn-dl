import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../downloader/models/download_item.dart';
import '../models/library_folder.dart';

class FolderCard extends StatefulWidget {
  const FolderCard({
    super.key,
    required this.folder,
    required this.onTap,
    this.onItemDropped,
    this.onOpenInExplorer,
    this.onRename,
    this.onDelete,
    this.onSyncPlaylist,
    this.onCopyPlaylistLink,
    this.onEditPlaylistLink,
  });

  final LibraryFolder folder;
  final VoidCallback onTap;
  final ValueChanged<DownloadItem>? onItemDropped;
  final VoidCallback? onOpenInExplorer;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onSyncPlaylist;
  final VoidCallback? onCopyPlaylistLink;
  final VoidCallback? onEditPlaylistLink;

  @override
  State<FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<FolderCard> {
  bool _isDragHovered = false;

  @override
  Widget build(BuildContext context) {
    final folder = widget.folder;

    return DragTarget<DownloadItem>(
      onWillAcceptWithDetails: (details) {
        final draggedItem = details.data;
        // Don't accept if already in this folder
        if (folder.isUnorganized &&
            (draggedItem.playlistName == null ||
                draggedItem.playlistName!.isEmpty)) {
          return false;
        }
        if (folder.isPlaylist &&
            draggedItem.playlistName?.trim() == folder.name.trim()) {
          return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        setState(() => _isDragHovered = false);
        widget.onItemDropped?.call(details.data);
      },
      onMove: (_) {
        if (!_isDragHovered) setState(() => _isDragHovered = true);
      },
      onLeave: (_) {
        if (_isDragHovered) setState(() => _isDragHovered = false);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _isDragHovered
                ? AppColors.primary.withValues(alpha: 0.04)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  _isDragHovered ? AppColors.primary : AppColors.surfaceBorder,
              width: _isDragHovered ? 2.0 : 1.0,
            ),
            boxShadow: _isDragHovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Thumbnail / Collage
                    _buildCoverArt(folder),
                    const SizedBox(width: 14),

                    // Folder Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildFolderBadge(folder),
                              if (_isDragHovered) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Drop to Move',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            folder.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${folder.count} ${folder.count == 1 ? 'item' : 'items'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (folder.formattedTotalSize.isNotEmpty) ...[
                                Text(' • ',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                                Text(
                                  folder.formattedTotalSize,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                              if (folder.audioCount > 0 &&
                                  folder.videoCount == 0) ...[
                                Text(' • ',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                                Text(
                                  'Audio',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ] else if (folder.videoCount > 0 &&
                                  folder.audioCount == 0) ...[
                                Text(' • ',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                                Text(
                                  'Video',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Actions Menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.surfaceBorder),
                      ),
                      onSelected: (val) {
                        if (val == 'open') {
                          widget.onTap();
                        } else if (val == 'sync') {
                          widget.onSyncPlaylist?.call();
                        } else if (val == 'copy_link') {
                          widget.onCopyPlaylistLink?.call();
                        } else if (val == 'edit_link') {
                          widget.onEditPlaylistLink?.call();
                        } else if (val == 'explorer') {
                          widget.onOpenInExplorer?.call();
                        } else if (val == 'rename') {
                          widget.onRename?.call();
                        } else if (val == 'delete') {
                          widget.onDelete?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              Icon(Icons.folder_open_rounded,
                                  size: 16, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('View Contents',
                                  style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        if (folder.isPlaylist && widget.onSyncPlaylist != null)
                          PopupMenuItem(
                            value: 'sync',
                            child: Row(
                              children: [
                                Icon(Icons.sync_rounded,
                                    size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Check & Download Missing',
                                    style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        if (folder.isPlaylist &&
                            folder.playlistUrl != null &&
                            folder.playlistUrl!.isNotEmpty &&
                            widget.onCopyPlaylistLink != null)
                          PopupMenuItem(
                            value: 'copy_link',
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded,
                                    size: 16, color: AppColors.textSecondary),
                                SizedBox(width: 8),
                                Text('Copy Playlist Link',
                                    style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        if (folder.isPlaylist &&
                            widget.onEditPlaylistLink != null)
                          PopupMenuItem(
                            value: 'edit_link',
                            child: Row(
                              children: [
                                Icon(Icons.link_rounded,
                                    size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  folder.playlistUrl != null &&
                                          folder.playlistUrl!.isNotEmpty
                                      ? 'Edit Playlist Link'
                                      : 'Attach Playlist Link',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        if (widget.onOpenInExplorer != null)
                          PopupMenuItem(
                            value: 'explorer',
                            child: Row(
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    size: 16, color: AppColors.textSecondary),
                                SizedBox(width: 8),
                                Text('Open in Explorer',
                                    style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        if (folder.isPlaylist && widget.onRename != null)
                          PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 16, color: AppColors.textSecondary),
                                SizedBox(width: 8),
                                Text('Rename Folder',
                                    style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        if (widget.onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded,
                                    size: 16, color: AppColors.error),
                                SizedBox(width: 8),
                                Text('Delete Folder...',
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
          ),
        );
      },
    );
  }

  Widget _buildCoverArt(LibraryFolder folder) {
    const size = 68.0;
    final thumbs = folder.previewThumbnailUrls;

    // If 4 thumbs available, display 2x2 collage
    if (thumbs.length >= 4) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildThumbTile(thumbs[0])),
                    const SizedBox(width: 1),
                    Expanded(child: _buildThumbTile(thumbs[1])),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildThumbTile(thumbs[2])),
                    const SizedBox(width: 1),
                    Expanded(child: _buildThumbTile(thumbs[3])),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If 1-3 thumbs available, display primary cover
    if (thumbs.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbTile(thumbs.first),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Icon(
                  folder.isVideos
                      ? Icons.play_circle_filled_rounded
                      : (folder.isUnorganized
                          ? Icons.folder_open_rounded
                          : Icons.queue_music_rounded),
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default icon placeholder
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Center(
        child: Icon(
          folder.isVideos
              ? Icons.videocam_rounded
              : (folder.isUnorganized
                  ? Icons.folder_special_rounded
                  : Icons.library_music_rounded),
          color: AppColors.primary,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildThumbTile(String url) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppColors.surfaceElevated,
          child: Icon(Icons.music_note_rounded,
              color: AppColors.textMuted, size: 14),
        ),
      ),
    );
  }

  Widget _buildFolderBadge(LibraryFolder folder) {
    String label;
    IconData icon;
    Color textColor;
    Color bgColor;

    if (folder.isUnorganized) {
      label = 'UNORGANIZED';
      icon = Icons.inbox_rounded;
      textColor = const Color(0xFFD97706); // Warm amber
      bgColor = const Color(0xFFFEF3C7);
    } else if (folder.isVideos) {
      label = 'VIDEOS';
      icon = Icons.movie_outlined;
      textColor = const Color(0xFF2563EB); // Royal blue
      bgColor = const Color(0xFFDBEAFE);
    } else {
      label = 'PLAYLIST';
      icon = Icons.playlist_play_rounded;
      textColor = AppColors.primary;
      bgColor = AppColors.surfaceElevated;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: textColor.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
