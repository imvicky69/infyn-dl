import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Centralized UI feedback utility that sanitizes backend/scraper errors
/// into clear, human-friendly messages and displays floating toasts.
class UiFeedbackHelper {
  UiFeedbackHelper._();

  /// Converts technical yt-dlp, network, or OS error strings into concise,
  /// user-friendly guidance without exposing raw Python tracebacks.
  static String sanitizeErrorMessage(String? rawError) {
    if (rawError == null || rawError.trim().isEmpty) {
      return 'Operation failed. Please try again.';
    }

    final lower = rawError.toLowerCase();

    // YouTube challenge / reload requirement
    if (lower.contains('the page needs to be reloaded') ||
        lower.contains('sign in to confirm') ||
        lower.contains('bot detection') ||
        lower.contains('challenge')) {
      return 'YouTube rate limit encountered. Please retry in a few seconds.';
    }

    // Network & timeout errors
    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('handshakeexception') ||
        lower.contains('timed out') ||
        lower.contains('timeout')) {
      return 'Network connection issue. Please check your internet connection.';
    }

    // HTTP 429 Too Many Requests
    if (lower.contains('429') || lower.contains('too many requests')) {
      return 'Too many requests. Please pause for a moment before retrying.';
    }

    // HTTP 403 Forbidden
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'Access temporarily restricted. Please try again shortly.';
    }

    // Storage / permission errors
    if (lower.contains('permission denied') ||
        lower.contains('access is denied') ||
        lower.contains('storage')) {
      return 'Storage permission error. Please verify app permissions in settings.';
    }

    // Video unavailable / removed
    if (lower.contains('video unavailable') ||
        lower.contains('private video') ||
        lower.contains('copyright')) {
      return 'This item is currently unavailable or restricted.';
    }

    // Strip out "[youtube]" prefixes and excessively long command lines
    if (rawError.startsWith('[youtube]') || rawError.startsWith('[download]')) {
      final parts = rawError.split(':');
      if (parts.length > 1) {
        final candidate = parts.sublist(1).join(':').trim();
        if (candidate.length < 120 && !candidate.contains('traceback')) {
          return candidate;
        }
      }
      return 'Failed to download track from YouTube. Please try again.';
    }

    // Fallback: keep short messages, summarize long traces
    if (rawError.length > 90) {
      return 'Download interrupted. Please check connection and retry.';
    }

    return rawError;
  }

  /// Displays a floating modern snackbar toast with an optional retry action.
  /// Strictly avoids any emojis, using Flutter Material icons instead.
  static void showErrorToast(
    BuildContext context,
    String? rawError, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    final message = sanitizeErrorMessage(rawError);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Displays a floating success toast with an optional icon.
  static void showSuccessToast(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
      ),
    );
  }
}
