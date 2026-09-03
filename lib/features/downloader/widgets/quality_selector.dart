import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/download_format.dart';
import '../models/media_quality.dart';
import '../models/video_metadata.dart';

class QualitySelector extends StatelessWidget {
  const QualitySelector({
    super.key,
    required this.format,
    required this.selectedVideoQuality,
    required this.selectedAudioQuality,
    required this.onVideoQualityChanged,
    required this.onAudioQualityChanged,
    this.metadata,
  });

  final DownloadFormat format;
  final VideoQuality selectedVideoQuality;
  final AudioQuality selectedAudioQuality;
  final ValueChanged<VideoQuality> onVideoQualityChanged;
  final ValueChanged<AudioQuality> onAudioQualityChanged;
  final VideoMetadata? metadata;

  String _formatSizeForQuality(VideoQuality quality) {
    if (metadata == null) return '';
    final match = metadata!.videoFormats.firstWhere(
      (f) => quality.height != null
          ? f.height == quality.height
          : f.height >= 1080,
      orElse: () => metadata!.videoFormats.isNotEmpty
          ? metadata!.videoFormats.first
          : const AvailableFormat(
              formatId: '',
              resolutionLabel: '',
              height: 0,
              totalSizeBytes: 0,
              formattedSize: '',
            ),
    );
    return match.formattedSize.isNotEmpty ? ' • ${match.formattedSize}' : '';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = format == DownloadFormat.mp4;
    final title = isVideo ? 'Video Resolution' : 'Audio Bitrate';
    final subtitle =
        isVideo ? selectedVideoQuality.subtitle : selectedAudioQuality.subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.1,
              ),
            ),
            const Spacer(),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isVideo)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VideoQuality.values.map((quality) {
              final isSelected = quality == selectedVideoQuality;
              final sizeSuffix = _formatSizeForQuality(quality);
              return _buildChip(
                label: '${quality.shortLabel}$sizeSuffix',
                isSelected: isSelected,
                onTap: () => onVideoQualityChanged(quality),
              );
            }).toList(),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AudioQuality.values.map((quality) {
              final isSelected = quality == selectedAudioQuality;
              final audioSize = metadata != null
                  ? ' • ${metadata!.formattedAudioSize(quality.qualityValue)}'
                  : '';
              return _buildChip(
                label: '${quality.shortLabel}$audioSize',
                isSelected: isSelected,
                onTap: () => onAudioQualityChanged(quality),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
          width: 1.0,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
