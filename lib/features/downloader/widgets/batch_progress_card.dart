import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/download_progress.dart';

/// Model representing individual active worker telemetry in a batch download.
class ActiveWorkerItem {
  final int workerId;
  final String title;
  final DownloadProgress progress;

  const ActiveWorkerItem({
    required this.workerId,
    required this.title,
    required this.progress,
  });
}

/// Progress card for batch playlist downloads with multi-worker acceleration telemetry.
class BatchProgressCard extends StatelessWidget {
  const BatchProgressCard({
    super.key,
    required this.playlistTitle,
    required this.currentIndex,
    required this.totalItems,
    required this.skippedCount,
    this.currentItemTitle = '',
    this.itemProgress,
    this.activeWorkers = const [],
    required this.onCancel,
    this.concurrency = 3,
  });

  final String playlistTitle;
  final int currentIndex;
  final int totalItems;
  final int skippedCount;
  final String currentItemTitle;
  final DownloadProgress? itemProgress;
  final List<ActiveWorkerItem> activeWorkers;
  final VoidCallback onCancel;
  final int concurrency;

  @override
  Widget build(BuildContext context) {
    final effectiveProcessed =
        (currentIndex + skippedCount).clamp(0, totalItems);
    final overallProgress = totalItems > 0
        ? (effectiveProcessed / totalItems).clamp(0.0, 1.0)
        : 0.0;
    final overallPercent = (overallProgress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.playlist_play_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlistTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Processed $effectiveProcessed of $totalItems ($overallPercent% overall)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (concurrency > 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 2),
                      Text(
                        '${concurrency}x Parallel',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Overall progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceElevated,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),

          // Active Items Section
          if (activeWorkers.length > 1) ...[
            Text(
              'ACTIVE DOWNLOADS (${activeWorkers.length})',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...activeWorkers.map((worker) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildWorkerCard(
                    title: worker.title,
                    progress: worker.progress,
                    workerId: worker.workerId,
                  ),
                )),
          ] else ...[
            _buildWorkerCard(
              title: activeWorkers.isNotEmpty
                  ? activeWorkers.first.title
                  : (currentItemTitle.isNotEmpty
                      ? currentItemTitle
                      : 'Downloading tracks in parallel...'),
              progress: activeWorkers.isNotEmpty
                  ? activeWorkers.first.progress
                  : (itemProgress ?? DownloadProgress.idle()),
            ),
          ],

          // Skipped badge if any
          if (skippedCount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  '$skippedCount duplicate${skippedCount > 1 ? 's' : ''} auto-skipped (already downloaded)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Cancel button
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: const Text(
                'Cancel Batch',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard({
    required String title,
    required DownloadProgress progress,
    int? workerId,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (workerId != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${workerId + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title.isNotEmpty ? title : 'Connecting to stream...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.progress > 0 ? progress.progress : null,
              minHeight: 4,
              backgroundColor: AppColors.surface,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progress.percentage.isNotEmpty ? progress.percentage : '0%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (progress.speed != null && progress.speed!.isNotEmpty)
                Text(
                  progress.speed!,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              if (progress.eta != null && progress.eta!.isNotEmpty)
                Text(
                  'ETA: ${progress.eta}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
