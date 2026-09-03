import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/download_format.dart';

class DownloadButton extends StatelessWidget {
  const DownloadButton({
    super.key,
    required this.onPressed,
    this.selectedFormat,
    this.qualityLabel,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final DownloadFormat? selectedFormat;
  final String? qualityLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    final formatLabel =
        selectedFormat != null ? ' ${selectedFormat!.label}' : '';
    final qualitySuffix = qualityLabel != null && qualityLabel!.isNotEmpty
        ? ' ($qualityLabel)'
        : '';

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: isEnabled ? null : AppColors.surfaceElevated,
        gradient: isEnabled ? AppColors.primaryGradient : null,
        borderRadius: BorderRadius.circular(18),
        border: isEnabled ? null : Border.all(color: AppColors.surfaceBorder),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Center(
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? AppColors.onPrimary.withValues(alpha: 0.2)
                              : AppColors.surfaceBorder,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          color:
                              isEnabled ? AppColors.onPrimary : AppColors.textMuted,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEnabled
                            ? 'Download$formatLabel$qualitySuffix'
                            : 'Select at least 1 track',
                        style: TextStyle(
                          color:
                              isEnabled ? AppColors.onPrimary : AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
