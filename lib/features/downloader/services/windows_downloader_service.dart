import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../../core/utils/process_path_resolver.dart';
import '../models/download_format.dart';
import '../models/download_progress.dart';
import '../models/media_quality.dart';
import '../models/playlist_metadata.dart';
import '../models/video_metadata.dart';
import 'downloader_service.dart';

/// Windows implementation of [DownloaderService] using bundled standalone
/// `yt-dlp.exe` and `ffmpeg.exe` without requiring Python.
class WindowsDownloaderService implements DownloaderService {
  Process? _activeProcess;
  bool _isCancelled = false;

  @override
  Future<VideoMetadata?> fetchMetadata(String url) async {
    if (kIsWeb) return null;

    final ytDlpPath = await ProcessPathResolver.resolveYtDlpPath();
    if (ytDlpPath == null) return null;

    var cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    final args = <String>[
      '--dump-single-json',
      '--no-playlist',
    ];

    final jsRuntime = await ProcessPathResolver.resolveJsRuntimeArg();
    if (jsRuntime != null) {
      args.addAll(['--js-runtimes', jsRuntime]);
    } else {
      args.addAll(['--extractor-args', 'youtube:player_client=android,web']);
    }

    args.add(cleanUrl);

    try {
      final result = await Process.run(ytDlpPath, args);
      if (result.exitCode == 0 && result.stdout is String) {
        final jsonMap =
            jsonDecode(result.stdout as String) as Map<String, dynamic>;
        return VideoMetadata.fromJson(jsonMap);
      }
    } catch (_) {
      // Ignore or return null on parsing/process failure
    }
    return null;
  }

  @override
  Future<PlaylistMetadata?> fetchPlaylistMetadata(String url) async {
    final ytDlpPath = await ProcessPathResolver.resolveYtDlpPath();
    if (ytDlpPath == null) return null;

    var cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    if (cleanUrl.contains('music.youtube.com/playlist')) {
      cleanUrl = cleanUrl.replaceAll(
          'music.youtube.com/playlist', 'www.youtube.com/playlist');
    }

    final args = <String>[
      '--flat-playlist',
      '--dump-single-json',
      '--yes-playlist',
      '--extractor-args',
      'youtube:player_client=android,web',
    ];

    final jsRuntime = await ProcessPathResolver.resolveJsRuntimeArg();
    if (jsRuntime != null) {
      args.addAll(['--js-runtimes', jsRuntime]);
    }

    args.add(cleanUrl);

    try {
      final result = await Process.run(ytDlpPath, args);
      if (result.exitCode == 0 && result.stdout is String) {
        final jsonMap =
            jsonDecode(result.stdout as String) as Map<String, dynamic>;
        return PlaylistMetadata.fromJson(jsonMap);
      }
    } catch (e) {
      debugPrint('WindowsDownloaderService.fetchPlaylistMetadata error: $e');
    }
    return null;
  }

  @override
  Future<bool> isAvailable() async {
    final ytDlp = await ProcessPathResolver.resolveYtDlpPath();
    return ytDlp != null;
  }

  @override
  Future<Map<String, String?>> getBackendInfo() async {
    final ytDlpPath = await ProcessPathResolver.resolveYtDlpPath();
    final ffmpegPath = await ProcessPathResolver.resolveFfmpegPath();
    final ffmpegDir = await ProcessPathResolver.resolveFfmpegDirectory();

    return {
      'ytDlpPath': ytDlpPath,
      'ffmpegPath': ffmpegPath,
      'ffmpegDir': ffmpegDir,
    };
  }

  @override
  Stream<DownloadProgress> download({
    required String url,
    required DownloadFormat format,
    VideoQuality videoQuality = VideoQuality.best,
    AudioQuality audioQuality = AudioQuality.k320,
    String? destinationDirectory,
  }) {
    final controller = StreamController<DownloadProgress>();

    () async {
      try {
        _isCancelled = false;

        if (kIsWeb) {
          controller.add(
            DownloadProgress.failed(
              'Browser Sandbox Limitation: Web browsers cannot spawn local Windows processes (yt-dlp.exe / ffmpeg.exe). To download media to your PC, launch the native Windows app: flutter run -d windows',
            ),
          );
          await controller.close();
          return;
        }

        // 1. Resolve executable binaries dynamically
        final ytDlpPath = await ProcessPathResolver.resolveYtDlpPath();
        if (ytDlpPath == null) {
          controller.add(
            DownloadProgress.failed(
              'yt-dlp.exe was not found. Please ensure it is present in windows/bin/x64 or system PATH.',
            ),
          );
          await controller.close();
          return;
        }

        final ffmpegDir = await ProcessPathResolver.resolveFfmpegDirectory();

        // 2. Resolve destination downloads directory
        final destDir = destinationDirectory ??
            await ProcessPathResolver.resolveDownloadsDirectory();
        final dir = Directory(destDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        controller.add(DownloadProgress.preparing());

        // 3. Assemble Windows process command arguments
        final outputTemplate = p.join(destDir, '%(title)s.%(ext)s');
        final args = <String>[
          '--newline',
          '--no-colors',
          '--no-playlist',
          '--windows-filenames',
          '--progress',
          '-N',
          '4',
        ];

        final jsRuntime = await ProcessPathResolver.resolveJsRuntimeArg();
        if (jsRuntime != null) {
          args.addAll(['--js-runtimes', jsRuntime]);
        } else {
          args.addAll(
              ['--extractor-args', 'youtube:player_client=android,web']);
        }

        args.addAll([
          '-o',
          outputTemplate,
        ]);

        if (ffmpegDir != null) {
          args.addAll(['--ffmpeg-location', ffmpegDir]);
        }

        if (format == DownloadFormat.mp4) {
          args.addAll([
            '-S',
            'res,size,br',
            '-f',
            videoQuality.ytDlpFormatString,
            '--merge-output-format',
            'mp4',
          ]);
        } else if (format == DownloadFormat.mp3) {
          args.addAll([
            '-x',
            '--audio-format',
            'mp3',
            '--audio-quality',
            audioQuality.qualityValue,
          ]);
        }

        var cleanUrl = url.trim();
        if (!cleanUrl.startsWith('http://') &&
            !cleanUrl.startsWith('https://')) {
          cleanUrl = 'https://$cleanUrl';
        }
        args.add(cleanUrl);

        // 4. Start local Windows child process
        try {
          _activeProcess = await Process.start(
            ytDlpPath,
            args,
            runInShell: false,
            workingDirectory: destDir,
          );
        } catch (e) {
          controller
              .add(DownloadProgress.failed('Failed to launch yt-dlp.exe: $e'));
          await controller.close();
          return;
        }

        final process = _activeProcess!;
        final stderrBuffer = StringBuffer();
        String? detectedTitle;
        String? detectedDestinationPath;
        var currentProgress = DownloadProgress.preparing();

        final progressRegex = RegExp(
          r'\[download\]\s+([\d\.]+)%\s+of\s+~?([^\s]+)\s+at\s+([^\s]+)\s+ETA\s+([^\s]+)',
        );
        final simplePercentRegex = RegExp(r'\[download\]\s+([\d\.]+)%');
        final destinationRegex = RegExp(r'Destination:\s+(.+)');
        final mergerRegex = RegExp(r'\[Merger\]\s+Merging formats into "(.+)"');
        final alreadyDownloadedRegex = RegExp(
          r'\[download\]\s+(.+)\s+has already been downloaded',
        );

        void handleLine(String line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return;

          if (destinationRegex.hasMatch(trimmed)) {
            final match = destinationRegex.firstMatch(trimmed);
            if (match != null && match.groupCount >= 1) {
              detectedDestinationPath = match.group(1)?.trim();
              if (detectedDestinationPath != null) {
                var clean =
                    p.basenameWithoutExtension(detectedDestinationPath!);
                clean = clean.replaceAll(RegExp(r'\.f[0-9]+$'), '');
                detectedTitle ??= clean;
              }
            }
          } else if (mergerRegex.hasMatch(trimmed)) {
            final match = mergerRegex.firstMatch(trimmed);
            if (match != null && match.groupCount >= 1) {
              detectedDestinationPath = match.group(1)?.trim();
              if (detectedDestinationPath != null) {
                var clean =
                    p.basenameWithoutExtension(detectedDestinationPath!);
                clean = clean.replaceAll(RegExp(r'\.f[0-9]+$'), '');
                detectedTitle = clean;
              }
            }
          } else if (alreadyDownloadedRegex.hasMatch(trimmed)) {
            final match = alreadyDownloadedRegex.firstMatch(trimmed);
            if (match != null && match.groupCount >= 1) {
              detectedDestinationPath = match.group(1)?.trim();
              if (detectedDestinationPath != null) {
                var clean =
                    p.basenameWithoutExtension(detectedDestinationPath!);
                clean = clean.replaceAll(RegExp(r'\.f[0-9]+$'), '');
                detectedTitle ??= clean;
              }
            }
          }

          if (trimmed.startsWith('[ExtractAudio]') ||
              trimmed.startsWith('[Merger]') ||
              trimmed.startsWith('[FixupM4a]')) {
            currentProgress = currentProgress.copyWith(
              status: DownloadStatus.processing,
              progress: 0.99,
              percentage: '99%',
              title: detectedTitle,
              rawLog: trimmed,
            );
            controller.add(currentProgress);
            return;
          }

          final fullMatch = progressRegex.firstMatch(trimmed);
          if (fullMatch != null) {
            final percentNum =
                double.tryParse(fullMatch.group(1) ?? '0') ?? 0.0;
            final totalSize = fullMatch.group(2);
            final speed = fullMatch.group(3);
            final eta = fullMatch.group(4);

            currentProgress = currentProgress.copyWith(
              status: DownloadStatus.downloading,
              progress: (percentNum / 100.0).clamp(0.0, 1.0),
              percentage: '${percentNum.toStringAsFixed(1)}%',
              totalSize: totalSize,
              speed: speed,
              eta: eta,
              title: detectedTitle,
              rawLog: trimmed,
            );
            controller.add(currentProgress);
            return;
          }

          final simpleMatch = simplePercentRegex.firstMatch(trimmed);
          if (simpleMatch != null) {
            final percentNum =
                double.tryParse(simpleMatch.group(1) ?? '0') ?? 0.0;
            currentProgress = currentProgress.copyWith(
              status: DownloadStatus.downloading,
              progress: (percentNum / 100.0).clamp(0.0, 1.0),
              percentage: '${percentNum.toStringAsFixed(1)}%',
              title: detectedTitle,
              rawLog: trimmed,
            );
            controller.add(currentProgress);
          }
        }

        final stdoutFuture = process.stdout
            .transform(systemEncoding.decoder)
            .transform(const LineSplitter())
            .forEach(handleLine);

        final stderrFuture = process.stderr
            .transform(systemEncoding.decoder)
            .transform(const LineSplitter())
            .forEach((line) {
          stderrBuffer.writeln(line);
          handleLine(line);
        });

        await Future.wait([stdoutFuture, stderrFuture]);
        final exitCode = await process.exitCode;
        _activeProcess = null;

        if (_isCancelled) {
          controller.add(DownloadProgress.cancelled(title: detectedTitle));
        } else if (exitCode == 0) {
          controller.add(DownloadProgress.completed(
            outputFilePath: detectedDestinationPath ?? destDir,
            title: detectedTitle,
          ));
        } else {
          final rawError = stderrBuffer.toString().trim();
          final cleanError = _formatErrorMessage(rawError);
          controller.add(DownloadProgress.failed(cleanError, rawLog: rawError));
        }
      } catch (e) {
        controller.add(DownloadProgress.failed('Process error: $e'));
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  @override
  Future<void> cancel() async {
    _isCancelled = true;
    final process = _activeProcess;
    if (process != null) {
      try {
        await Process.run('taskkill', ['/F', '/T', '/PID', '${process.pid}']);
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
      }
      _activeProcess = null;
    }
  }

  String _formatErrorMessage(String raw) {
    if (raw.isEmpty) {
      return 'Download failed with non-zero exit code.';
    }
    if (raw.contains('Private video')) {
      return 'This video is private and cannot be downloaded.';
    }
    if (raw.contains('Video unavailable')) {
      return 'The requested YouTube video is unavailable.';
    }
    if (raw.contains('Incomplete YouTube ID') ||
        raw.contains('not a valid URL')) {
      return 'Invalid YouTube URL provided.';
    }
    if (raw.contains('Sign in to confirm your age')) {
      return 'This video requires age confirmation.';
    }

    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('WARNING'))
        .toList();
    return lines.isNotEmpty ? lines.last : raw;
  }
}
