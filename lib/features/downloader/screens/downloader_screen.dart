import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/download_format.dart';
import '../models/download_progress.dart';
import '../models/media_quality.dart';
import '../models/video_metadata.dart';
import '../services/downloader_service.dart';
import '../services/windows_downloader_service.dart';
import '../widgets/download_button.dart';
import '../widgets/download_progress_card.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/format_selector.dart';
import '../widgets/quality_selector.dart';
import '../widgets/url_input_field.dart';
import '../widgets/video_preview_card.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({
    super.key,
    this.downloaderService,
  });

  /// Optional injected service for testing and platform substitution
  final DownloaderService? downloaderService;

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  late final DownloaderService _downloaderService;
  StreamSubscription<DownloadProgress>? _downloadSubscription;

  DownloadFormat _selectedFormat = DownloadFormat.mp4;
  VideoQuality _selectedVideoQuality = VideoQuality.best;
  AudioQuality _selectedAudioQuality = AudioQuality.k320;
  DownloadProgress _downloadProgress = DownloadProgress.idle();
  String? _errorMessage;
  VideoMetadata? _metadata;
  bool _isFetchingMetadata = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _downloaderService = widget.downloaderService ?? WindowsDownloaderService();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _downloadSubscription?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  bool _isValidYoutubeUrl(String input) {
    var trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('music.youtube.com');
  }

  void _handleUrlChanged(String value) {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }

    _debounceTimer?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _metadata = null;
      });
      return;
    }

    if (_isValidYoutubeUrl(trimmed)) {
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _fetchMetadata(trimmed);
      });
    }
  }

  Future<void> _fetchMetadata(String rawUrl) async {
    if (_isFetchingMetadata) return;

    setState(() {
      _isFetchingMetadata = true;
    });

    try {
      final meta = await _downloaderService.fetchMetadata(rawUrl);
      if (!mounted) return;
      setState(() {
        _metadata = meta;
        _isFetchingMetadata = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFetchingMetadata = false;
      });
    }
  }

  void _handleFormatChanged(DownloadFormat format) {
    if (_downloadProgress.isActive) return;
    setState(() {
      _selectedFormat = format;
    });
  }

  Future<void> _handleDownload() async {
    if (_downloadProgress.isActive) return;

    var url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter or paste a YouTube URL';
      });
      return;
    }

    if (!_isValidYoutubeUrl(url)) {
      setState(() {
        _errorMessage = 'Please enter a valid YouTube video or Shorts link';
      });
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    setState(() {
      _errorMessage = null;
      _downloadProgress = DownloadProgress.preparing();
    });

    _downloadSubscription?.cancel();

    _downloadSubscription = _downloaderService
        .download(
      url: url,
      format: _selectedFormat,
      videoQuality: _selectedVideoQuality,
      audioQuality: _selectedAudioQuality,
    )
        .listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = progress;
        });

        if (progress.isCompleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Media downloaded successfully!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = DownloadProgress.failed('Unexpected error: $error');
        });
      },
    );
  }

  Future<void> _handleCancel() async {
    await _downloaderService.cancel();
    if (!mounted) return;
    setState(() {
      _downloadProgress = DownloadProgress.cancelled();
    });
  }

  void _handleDismissProgress() {
    setState(() {
      _downloadProgress = DownloadProgress.idle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDownloading = _downloadProgress.isActive;
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: isDesktop ? 32 : 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 620 : double.infinity,
              ),
              child: Container(
                decoration: isDesktop
                    ? BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.surfaceBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 24,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      )
                    : null,
                padding: isDesktop
                    ? const EdgeInsets.all(32)
                    : EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clean App Header with assets/logo-clear.png
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/logo-clear.png',
                            height: 36,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text(
                                  'i',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'infyn-yt',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Modern YouTube Downloader',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDesktop ? AppColors.surfaceElevated : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: kIsWeb ? Colors.orange : AppColors.success,
                                size: 7,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                kIsWeb ? 'Web Preview' : 'Ready',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Minimal Hero Section
                    const Text(
                      'infyn-yt',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Download videos in up to 4K MP4 or extract 320kbps MP3 audio.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // URL Input
                    UrlInputField(
                      controller: _urlController,
                      onChanged: _handleUrlChanged,
                      onSubmitted: (_) => _handleDownload(),
                      errorText: _errorMessage,
                    ),

                    // Metadata loading indicator
                    if (_isFetchingMetadata) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Fetching video details & real format file sizes...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Video preview card
                    if (_metadata != null) ...[
                      const SizedBox(height: 12),
                      VideoPreviewCard(metadata: _metadata!),
                    ],

                    const SizedBox(height: 16),

                    // Format Selector (MP4 / MP3 cards)
                    FormatSelector(
                      selectedFormat: _selectedFormat,
                      onFormatChanged: _handleFormatChanged,
                    ),
                    const SizedBox(height: 16),

                    // Quality Selector
                    QualitySelector(
                      format: _selectedFormat,
                      selectedVideoQuality: _selectedVideoQuality,
                      selectedAudioQuality: _selectedAudioQuality,
                      metadata: _metadata,
                      onVideoQualityChanged: (quality) {
                        if (_downloadProgress.isActive) return;
                        setState(() {
                          _selectedVideoQuality = quality;
                        });
                      },
                      onAudioQualityChanged: (quality) {
                        if (_downloadProgress.isActive) return;
                        setState(() {
                          _selectedAudioQuality = quality;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Download Action Button
                    DownloadButton(
                      key: const Key('download_action_button'),
                      onPressed: isDownloading ? null : _handleDownload,
                      selectedFormat: _selectedFormat,
                      qualityLabel: _selectedFormat == DownloadFormat.mp4
                          ? _selectedVideoQuality.shortLabel
                          : _selectedAudioQuality.shortLabel,
                      isLoading: isDownloading,
                    ),

                    // Live Download Progress & Cancellation Card
                    if (_downloadProgress.status != DownloadStatus.idle) ...[
                      const SizedBox(height: 16),
                      DownloadProgressCard(
                        key: const Key('download_progress_card'),
                        progress: _downloadProgress,
                        onCancel: _handleCancel,
                        onDismiss: _handleDismissProgress,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Minimalist Guide
                    const EmptyStateCard(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
