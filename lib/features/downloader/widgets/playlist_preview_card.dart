import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/playlist_metadata.dart';

/// Clean card presenting fetched YouTube / YouTube Music playlist details
/// with interactive item-selection controls (Select/Deselect All, individual checkboxes).
class PlaylistPreviewCard extends StatefulWidget {
  const PlaylistPreviewCard({
    super.key,
    required this.playlist,
    required this.selectedIndices,
    required this.onSelectionChanged,
    this.alreadyDownloadedIndices = const {},
  });

  final PlaylistMetadata playlist;
  final Set<int> selectedIndices;
  final ValueChanged<Set<int>> onSelectionChanged;
  final Set<int> alreadyDownloadedIndices;

  @override
  State<PlaylistPreviewCard> createState() => _PlaylistPreviewCardState();
}

class _PlaylistPreviewCardState extends State<PlaylistPreviewCard> {
  bool _isExpanded = false;

  Set<int> get _selectableIndices {
    final total = widget.playlist.entries.length;
    return Set.from(
      List.generate(total, (i) => i)
          .where((i) => !widget.alreadyDownloadedIndices.contains(i)),
    );
  }

  void _toggleSelectAll() {
    final selectable = _selectableIndices;
    if (widget.selectedIndices.length == selectable.length &&
        selectable.isNotEmpty) {
      // Deselect all
      widget.onSelectionChanged({});
    } else {
      // Select all selectable
      widget.onSelectionChanged(selectable);
    }
  }

  void _toggleIndex(int index) {
    if (widget.alreadyDownloadedIndices.contains(index)) return;

    final updated = Set<int>.from(widget.selectedIndices);
    if (updated.contains(index)) {
      updated.remove(index);
    } else {
      updated.add(index);
    }
    widget.onSelectionChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final playlist = widget.playlist;
    final total = playlist.entries.length;
    final selectedCount = widget.selectedIndices.length;
    final selectableCount = _selectableIndices.length;
    final isAllSelected =
        selectedCount == selectableCount && selectableCount > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Playlist icon badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.playlist_play_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // Playlist info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (playlist.uploader != null) ...[
                            Text(
                              playlist.uploader!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(' • ',
                                style: TextStyle(color: AppColors.textMuted)),
                          ],
                          Text(
                            '$selectedCount of $total selected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selectedCount > 0
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                          if (widget.alreadyDownloadedIndices.isNotEmpty) ...[
                            Text(' • ',
                                style: TextStyle(color: AppColors.textMuted)),
                            Text(
                              '${widget.alreadyDownloadedIndices.length} in library',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Toggle tracks view
                if (playlist.entries.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    tooltip: _isExpanded ? 'Hide items' : 'View items',
                  ),
              ],
            ),
          ),

          // Action bar for Select All / Deselect All
          if (playlist.entries.isNotEmpty) ...[
            Divider(height: 1, color: AppColors.surfaceBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isExpanded
                        ? 'Select tracks to download:'
                        : 'Click arrow to preview/choose tracks',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  InkWell(
                    onTap: _toggleSelectAll,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Text(
                        isAllSelected
                            ? 'Deselect All'
                            : 'Select All (${_selectableIndices.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Collapsible track list preview with checkboxes
          if (_isExpanded && playlist.entries.isNotEmpty) ...[
            Divider(height: 1, color: AppColors.surfaceBorder),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: playlist.entries.length,
                separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 48,
                    endIndent: 14,
                    color: AppColors.surfaceBorder),
                itemBuilder: (context, index) {
                  final entry = playlist.entries[index];
                  final isAlreadyDownloaded =
                      widget.alreadyDownloadedIndices.contains(index);
                  final isSelected = widget.selectedIndices.contains(index);

                  return InkWell(
                    onTap:
                        isAlreadyDownloaded ? null : () => _toggleIndex(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          if (isAlreadyDownloaded)
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Color(0xFF10B981),
                                size: 14,
                              ),
                            )
                          else
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: isSelected,
                                activeColor: AppColors.primary,
                                checkColor: AppColors.onPrimary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                                side: BorderSide(
                                    color: AppColors.textMuted, width: 1.5),
                                onChanged: (_) => _toggleIndex(index),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            '${index + 1}.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isAlreadyDownloaded
                                  ? AppColors.textMuted
                                  : (isSelected
                                      ? AppColors.textSecondary
                                      : AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isAlreadyDownloaded
                                          ? AppColors.textMuted
                                          : (isSelected
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isAlreadyDownloaded) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'In Library',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (entry.duration > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              entry.formattedDuration,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
