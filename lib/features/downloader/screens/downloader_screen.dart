import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_opener.dart';
import '../../settings/services/settings_service.dart';
import '../models/download_format.dart';
import '../models/download_item.dart';
import '../models/download_progress.dart';
import '../models/media_quality.dart';
import '../models/playlist_metadata.dart';
import '../models/video_metadata.dart';
import '../services/android_downloader_service.dart';
import '../services/download_history_service.dart';
import '../services/downloader_service.dart';
import '../services/windows_downloader_service.dart';
import '../widgets/batch_progress_card.dart';
import '../widgets/download_button.dart';
import '../widgets/download_progress_card.dart';
import '../widgets/format_selector.dart';
import '../widgets/playlist_preview_card.dart';
import '../widgets/quality_selector.dart';
import '../widgets/url_input_field.dart';
import '../widgets/video_preview_card.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({
    super.key,
    this.downloaderService,
    this.onOpenSettings,
    this.onOpenLibrary,
  });

  final DownloaderService? downloaderService;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenLibrary;

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
  PlaylistMetadata? _playlistMetadata;
  bool _isFetchingMetadata = false;
  Timer? _debounceTimer;

  // Batch playlist state
  bool _isBatchDownloading = false;
  Set<int> _selectedPlaylistIndices = {};
  int _batchCurrentIndex = 0;
  int _batchTotalItems = 0;
  int _batchSkippedCount = 0;
  String _batchCurrentTitle = '';
  DownloadProgress _batchItemProgress = DownloadProgress.idle();
  bool _isBatchCancelled = false;

  String _currentDownloadDir = 'Loading folder...';
  List<DownloadItem> _recentDownloads = [];

  @override
  void initState() {
    super.initState();
    _downloaderService = widget.downloaderService ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? AndroidDownloaderService()
            : WindowsDownloaderService());
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await SettingsService.instance.init();
    final dir = await SettingsService.instance.resolveDownloadDirectory();
    final history = await DownloadHistoryService.instance.getHistory();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final service = _downloaderService;
      final androidService = service is AndroidDownloaderService
          ? service
          : AndroidDownloaderService();
      final hasPerm = await androidService.hasNotificationPermission();
      if (!hasPerm) {
        await androidService.requestNotificationPermission();
      }
    }

    if (mounted) {
      setState(() {
        _currentDownloadDir = dir;
        _recentDownloads = history.take(2).toList();
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _downloadSubscription?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  bool _isValidUrl(String input) {
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

  bool _isPlaylistUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('list=') || lower.contains('/playlist');
  }

  bool _isYouTubeMusicUrl(String url) {
    return url.toLowerCase().contains('music.youtube.com');
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
        _playlistMetadata = null;
      });
      return;
    }

    if (_isValidUrl(trimmed)) {
      if (_isYouTubeMusicUrl(trimmed) &&
          _selectedFormat != DownloadFormat.mp3) {
        setState(() {
          _selectedFormat = DownloadFormat.mp3;
        });
      }

      _debounceTimer = Timer(const Duration(milliseconds: 450), () {
        _fetchDetails(trimmed);
      });
    }
  }

  Future<void> _fetchDetails(String rawUrl) async {
    if (_isFetchingMetadata) return;

    setState(() {
      _isFetchingMetadata = true;
      _metadata = null;
      _playlistMetadata = null;
    });

    try {
      var queryUrl = rawUrl.trim();
      if (queryUrl.contains('music.youtube.com/playlist')) {
        queryUrl = queryUrl.replaceAll(
            'music.youtube.com/playlist', 'www.youtube.com/playlist');
      }

      if (_isPlaylistUrl(queryUrl)) {
        final playlist =
            await _downloaderService.fetchPlaylistMetadata(queryUrl);
        if (!mounted) return;
        if (playlist != null && playlist.entries.isNotEmpty) {
          setState(() {
            _playlistMetadata = playlist;
            _selectedPlaylistIndices =
                Set.from(List.generate(playlist.entries.length, (i) => i));
            _isFetchingMetadata = false;
          });
          return;
        }
      }

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

  Future<void> _pickDownloadDirectory() async {
    try {
      final selected = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Download Folder',
      );
      if (selected != null && selected.isNotEmpty) {
        await SettingsService.instance.setCustomDownloadPath(selected);
        final resolved =
            await SettingsService.instance.resolveDownloadDirectory();
        if (mounted) {
          setState(() {
            _currentDownloadDir = resolved;
          });
          _showSnackbar('Download folder set to: $resolved');
        }
      }
    } catch (e) {
      _showSnackbar('Could not open folder picker: $e', isError: true);
    }
  }

  void _handleFormatChanged(DownloadFormat format) {
    if (_downloadProgress.isActive || _isBatchDownloading) return;
    setState(() {
      _selectedFormat = format;
    });
  }

  Future<void> _handleDownload() async {
    if (_downloadProgress.isActive || _isBatchDownloading) return;

    var url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter or paste a YouTube URL';
      });
      return;
    }

    if (!_isValidUrl(url)) {
      setState(() {
        _errorMessage = 'Please enter a valid YouTube or YouTube Music link';
      });
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    if (_playlistMetadata != null && _playlistMetadata!.entries.isNotEmpty) {
      await _startBatchPlaylistDownload(url);
    } else {
      await _startSingleDownload(url);
    }
  }

  Future<void> _startSingleDownload(String url) async {
    final destDir = await SettingsService.instance.resolveDownloadDirectory();

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
      destinationDirectory: destDir,
    )
        .listen(
      (progress) async {
        if (!mounted) return;
        setState(() {
          _downloadProgress = progress;
        });

        if (progress.isCompleted) {
          final downloadItem = DownloadItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: progress.title ?? _metadata?.title ?? 'YouTube Media',
            url: url,
            filePath: progress.outputFilePath ?? '',
            format: _selectedFormat,
            quality: _selectedFormat == DownloadFormat.mp4
                ? _selectedVideoQuality.shortLabel
                : _selectedAudioQuality.shortLabel,
            thumbnailUrl: _metadata?.thumbnailUrl,
            timestamp: DateTime.now(),
          );
          await DownloadHistoryService.instance.addDownload(downloadItem);
          _loadInitialData();

          _showSnackbar('Download completed and saved!');
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = DownloadProgress.failed('Download error: $error');
        });
      },
    );
  }

  Future<void> _startBatchPlaylistDownload(String playlistUrl) async {
    final playlist = _playlistMetadata!;
    final baseDir = await SettingsService.instance.resolveDownloadDirectory();
    final autoSkip = SettingsService.instance.autoSkipDuplicates;
    final useSubfolder = SettingsService.instance.playlistSubfolder;
    final concurrency = SettingsService.instance.concurrentDownloads;

    final targetFolder = useSubfolder
        ? p.join(baseDir, _sanitizeFolderName(playlist.title))
        : baseDir;

    final targetDir = Directory(targetFolder);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetIndices = _selectedPlaylistIndices
        .where((i) => i < playlist.entries.length)
        .toList()
      ..sort();

    if (targetIndices.isEmpty) {
      _showSnackbar('No playlist tracks selected', isError: true);
      return;
    }

    setState(() {
      _isBatchDownloading = true;
      _isBatchCancelled = false;
      _batchTotalItems = targetIndices.length;
      _batchCurrentIndex = 0;
      _batchSkippedCount = 0;
      _batchCurrentTitle = '';
      _batchItemProgress = DownloadProgress.idle();
    });

    final total = targetIndices.length;
    var nextItemIndex = 0;
    var completedCount = 0;
    final activeSubscriptions = <StreamSubscription>[];

    Future<void> downloadWorker(int workerId) async {
      while (!_isBatchCancelled) {
        int listIndex;
        if (nextItemIndex >= total) break;
        listIndex = nextItemIndex++;

        final originalIndex = targetIndices[listIndex];
        final entry = playlist.entries[originalIndex];

        if (autoSkip) {
          final isDuplicate =
              await DownloadHistoryService.instance.isAlreadyDownloaded(
            title: entry.title,
            format: _selectedFormat,
            targetDirectory: targetFolder,
          );

          if (isDuplicate) {
            if (mounted) {
              setState(() {
                _batchSkippedCount++;
                _batchCurrentIndex = completedCount + _batchSkippedCount;
              });
            }
            continue;
          }
        }

        if (_isBatchCancelled) break;

        if (mounted) {
          setState(() {
            _batchCurrentTitle = entry.title;
            _batchItemProgress = DownloadProgress.preparing();
          });
        }

        final completer = Completer<void>();
        StreamSubscription<DownloadProgress>? itemSub;

        itemSub = _downloaderService
            .download(
          url: entry.url,
          format: _selectedFormat,
          videoQuality: _selectedVideoQuality,
          audioQuality: _selectedAudioQuality,
          destinationDirectory: targetFolder,
        )
            .listen(
          (progress) async {
            if (!mounted) return;
            setState(() {
              _batchItemProgress = progress;
              _batchCurrentTitle = entry.title;
            });

            if (progress.isCompleted) {
              final downloadItem = DownloadItem(
                id: '${DateTime.now().millisecondsSinceEpoch}_$originalIndex',
                title: entry.title,
                url: entry.url,
                filePath: progress.outputFilePath ?? '',
                format: _selectedFormat,
                quality: _selectedFormat == DownloadFormat.mp4
                    ? _selectedVideoQuality.shortLabel
                    : _selectedAudioQuality.shortLabel,
                playlistName: playlist.title,
                timestamp: DateTime.now(),
              );
              await DownloadHistoryService.instance.addDownload(downloadItem);

              if (mounted) {
                completedCount++;
                setState(() {
                  _batchCurrentIndex = completedCount + _batchSkippedCount;
                });
              }

              itemSub?.cancel();
              if (!completer.isCompleted) completer.complete();
            } else if (progress.isFailed || progress.isCancelled) {
              itemSub?.cancel();
              if (!completer.isCompleted) completer.complete();
            }
          },
          onError: (_) {
            itemSub?.cancel();
            if (!completer.isCompleted) completer.complete();
          },
        );

        activeSubscriptions.add(itemSub);
        await completer.future;
        await itemSub.cancel();
        activeSubscriptions.remove(itemSub);
      }
    }

    final workerCount = concurrency.clamp(1, total);
    final workers = List.generate(workerCount, (id) => downloadWorker(id));
    await Future.wait(workers);

    for (final sub in activeSubscriptions) {
      await sub.cancel();
    }

    if (mounted) {
      setState(() {
        _isBatchDownloading = false;
      });
      _loadInitialData();
      _showSnackbar(
        _isBatchCancelled
            ? 'Playlist download cancelled'
            : 'Playlist download complete! ($completedCount downloaded, $_batchSkippedCount skipped)',
      );
    }
  }

  Future<void> _handleCancel() async {
    if (_isBatchDownloading) {
      _isBatchCancelled = true;
    }
    await _downloaderService.cancel();
    if (!mounted) return;
    setState(() {
      _downloadProgress = DownloadProgress.cancelled();
      _isBatchDownloading = false;
    });
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _sanitizeFolderName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final hasDetails = _metadata != null || _playlistMetadata != null;

    final parts = _currentDownloadDir.split(Platform.pathSeparator);
    final displayDir = parts.length > 2
        ? parts.sublist(parts.length - 2).join(Platform.pathSeparator)
        : _currentDownloadDir;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Sleek Modern App Header
                  _buildHeader(displayDir),
                  const SizedBox(height: 24),

                  // 2. Main Search / Link Input Box
                  UrlInputField(
                    controller: _urlController,
                    onChanged: _handleUrlChanged,
                    onSubmitted: (_) =>
                        _fetchDetails(_urlController.text.trim()),
                    errorText: _errorMessage,
                  ),

                  // 3. Loading State Card
                  if (_isFetchingMetadata) ...[
                    const SizedBox(height: 18),
                    _buildLoadingCard(),
                  ],

                  // 4. Fetched Media Preview & Download Controls
                  if (hasDetails) ...[
                    const SizedBox(height: 20),
                    if (_metadata != null)
                      VideoPreviewCard(metadata: _metadata!),
                    if (_playlistMetadata != null)
                      PlaylistPreviewCard(
                        playlist: _playlistMetadata!,
                        selectedIndices: _selectedPlaylistIndices,
                        onSelectionChanged: (set) =>
                            setState(() => _selectedPlaylistIndices = set),
                      ),
                    const SizedBox(height: 18),
                    FormatSelector(
                      selectedFormat: _selectedFormat,
                      onFormatChanged: _handleFormatChanged,
                    ),
                    const SizedBox(height: 16),
                    QualitySelector(
                      format: _selectedFormat,
                      selectedVideoQuality: _selectedVideoQuality,
                      selectedAudioQuality: _selectedAudioQuality,
                      metadata: _metadata,
                      onVideoQualityChanged: (quality) {
                        if (_downloadProgress.isActive || _isBatchDownloading) {
                          return;
                        }
                        setState(() => _selectedVideoQuality = quality);
                      },
                      onAudioQualityChanged: (quality) {
                        if (_downloadProgress.isActive || _isBatchDownloading) {
                          return;
                        }
                        setState(() => _selectedAudioQuality = quality);
                      },
                    ),
                    const SizedBox(height: 22),
                    DownloadButton(
                      key: const Key('download_action_button'),
                      selectedFormat: _selectedFormat,
                      qualityLabel: _playlistMetadata != null
                          ? '${_selectedPlaylistIndices.length} items'
                          : (_selectedFormat == DownloadFormat.mp4
                              ? _selectedVideoQuality.shortLabel
                              : _selectedAudioQuality.shortLabel),
                      isLoading:
                          _downloadProgress.isActive || _isBatchDownloading,
                      onPressed: (_playlistMetadata != null &&
                              _selectedPlaylistIndices.isEmpty)
                          ? null
                          : _handleDownload,
                    ),
                  ],

                  // 5. Active Single Download Progress
                  if (_downloadProgress.isActive ||
                      _downloadProgress.isCompleted ||
                      _downloadProgress.isFailed ||
                      _downloadProgress.isCancelled) ...[
                    const SizedBox(height: 18),
                    DownloadProgressCard(
                      key: const Key('download_progress_card'),
                      progress: _downloadProgress,
                      onCancel: _handleCancel,
                      onDismiss: () => setState(
                          () => _downloadProgress = DownloadProgress.idle()),
                    ),
                  ],

                  // 6. Active Batch Playlist Progress
                  if (_isBatchDownloading) ...[
                    const SizedBox(height: 18),
                    BatchProgressCard(
                      playlistTitle:
                          _playlistMetadata?.title ?? 'Batch Playlist',
                      currentIndex: _batchCurrentIndex,
                      totalItems: _batchTotalItems,
                      skippedCount: _batchSkippedCount,
                      currentItemTitle: _batchCurrentTitle,
                      itemProgress: _batchItemProgress,
                      concurrency: SettingsService.instance.concurrentDownloads,
                      onCancel: _handleCancel,
                    ),
                  ],

                  // 7. Clean Idle State (When no link is loaded)
                  if (!hasDetails &&
                      !_isFetchingMetadata &&
                      !_downloadProgress.isActive &&
                      !_isBatchDownloading) ...[
                    const SizedBox(height: 28),
                    _buildQuickActionCards(),
                    if (_recentDownloads.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _buildRecentDownloadsPreview(),
                    ],
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String displayDir) {
    return Row(
      children: [
        // App Logo Icon
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.all_inclusive_rounded,
              size: 32,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Brand Title
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Infyn DL',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Row(
              children: [
                Icon(Icons.circle, size: 6, color: AppColors.success),
                SizedBox(width: 5),
                Text(
                  'Engine Ready',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),

        // Destination Folder Pill
        InkWell(
          onTap: _pickDownloadDirectory,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    displayDir,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fetching media details...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Extracting streams and available qualities',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCards() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.headphones_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '320k Audio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Pristine MP3 music & audio extraction',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.movie_filter_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '4K & 1080p',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'High-res video with original audio',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentDownloadsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RECENT DOWNLOADS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            if (widget.onOpenLibrary != null)
              InkWell(
                onTap: widget.onOpenLibrary,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'View All →',
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
        const SizedBox(height: 12),
        ..._recentDownloads.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.format == DownloadFormat.mp3
                        ? Icons.music_note_rounded
                        : Icons.videocam_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.format.name.toUpperCase()} • ${item.quality} ${item.formattedFileSize.isNotEmpty ? "• ${item.formattedFileSize}" : ""}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.play_circle_fill_rounded,
                    size: 26,
                    color: AppColors.primary,
                  ),
                  onPressed: () => FileOpener.open(item.filePath),
                  tooltip: 'Play',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
