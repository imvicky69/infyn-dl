import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_opener.dart';
import '../models/download_progress.dart';

class DownloadProgressCard extends StatelessWidget {
  const DownloadProgressCard({
    super.key,
    required this.progress,
    required this.onCancel,
    required this.onDismiss,
  });

  final DownloadProgress progress;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;

  Future<void> _openDestinationFolder(String filePath) async {
    try {
      final file = File(filePath);
      final dirPath = (await file.exists()) ? p.dirname(filePath) : filePath;
      await FileOpener.open(dirPath);
    } catch (_) {
      // Ignore open errors
    }
  }

  @override
  Widget build(BuildContext context) {
    if (progress.status == DownloadStatus.idle) {
      return const SizedBox.shrink();
    }

    final isCompleted = progress.isCompleted;
    final isFailed = progress.isFailed;
    final isCancelled = progress.isCancelled;
    final isActive = progress.isActive;

    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    if (isCompleted) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
      statusTitle = 'Download Completed';
    } else if (isFailed) {
      statusColor = Theme.of(context).colorScheme.error;
      statusIcon = Icons.error_rounded;
      statusTitle = 'Download Failed';
    } else if (isCancelled) {
      statusColor = AppColors.textMuted;
      statusIcon = Icons.cancel_rounded;
      statusTitle = 'Download Cancelled';
    } else if (progress.status == DownloadStatus.processing) {
      statusColor = AppColors.primary;
      statusIcon = Icons.autorenew_rounded;
      statusTitle = 'Converting with FFmpeg...';
    } else if (progress.status == DownloadStatus.downloading) {
      statusColor = AppColors.primary;
      statusIcon = Icons.arrow_downward_rounded;
      statusTitle = 'Downloading ${progress.percentage}';
    } else {
      statusColor = AppColors.primary;
      statusIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Connecting to YouTube...';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withValues(alpha: 0.4)
              : (isFailed
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.4)
                  : AppColors.surfaceBorder),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    if (progress.title != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        progress.title!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (!isActive)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: AppColors.textMuted,
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar
          if (isActive || isCompleted) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: isActive && progress.status == DownloadStatus.preparing
                      ? null
                      : progress.progress,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Metrics Row (Speed, ETA, Size)
            if (isActive && progress.status == DownloadStatus.downloading)
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _buildMetric(
                    label: 'Speed',
                    value: progress.speed ?? '--',
                    icon: Icons.speed_rounded,
                  ),
                  _buildMetric(
                    label: 'ETA',
                    value: progress.eta ?? '--',
                    icon: Icons.timer_outlined,
                  ),
                  _buildMetric(
                    label: 'Size',
                    value: progress.totalSize ?? '--',
                    icon: Icons.data_usage_rounded,
                  ),
                ],
              ),
          ],

          // Completed Details
          if (isCompleted && progress.outputFilePath != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_open_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved: ${p.basename(progress.outputFilePath!)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () =>
                        _openDestinationFolder(progress.outputFilePath!),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 28),
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Open Folder',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],

          // Error Message
          if (isFailed && progress.errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFCA5A5),
                ),
              ),
              child: Text(
                progress.errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                  height: 1.35,
                ),
              ),
            ),
          ],

          // Cancel Action while active
          if (isActive) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.stop_circle_outlined, size: 15),
                  label: const Text('Cancel Download'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
