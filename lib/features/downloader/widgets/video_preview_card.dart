import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/video_metadata.dart';

class VideoPreviewCard extends StatelessWidget {
  const VideoPreviewCard({
    super.key,
    required this.metadata,
  });

  final VideoMetadata metadata;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with duration overlay
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 120,
              height: 70,
              color: AppColors.surfaceElevated,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (metadata.thumbnailUrl != null)
                    Image.network(
                      metadata.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.play_circle_outline_rounded,
                            color: AppColors.textMuted, size: 28),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.play_circle_outline_rounded,
                          color: AppColors.textMuted, size: 28),
                    ),
                  if (metadata.formattedDuration.isNotEmpty)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          metadata.formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Channel info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metadata.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metadata.uploader != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.account_circle_outlined,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          metadata.uploader!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
