import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Utility class for dynamically resolving Windows executable binaries (yt-dlp, FFmpeg)
/// and system download directories without hardcoded paths.
class ProcessPathResolver {
  ProcessPathResolver._();

  /// Resolves the absolute path to `yt-dlp.exe`.
  ///
  /// Resolution order:
  /// 1. Installed runtime bundle subdirectory: `<AppDir>/bin/yt-dlp.exe`
  /// 2. Installed runtime bundle root: `<AppDir>/yt-dlp.exe`
  /// 3. Development / source repository tree: `<ProjectRoot>/windows/bin/x64/yt-dlp.exe`
  /// 4. System PATH fallback
  static Future<String?> resolveYtDlpPath() async {
    if (kIsWeb) return null;
    return _resolveBinary('yt-dlp.exe');
  }

  /// Resolves the absolute path to `ffmpeg.exe`.
  ///
  /// Resolution order:
  /// 1. Installed runtime bundle subdirectory: `<AppDir>/bin/ffmpeg.exe`
  /// 2. Installed runtime bundle root: `<AppDir>/ffmpeg.exe`
  /// 3. Development / source repository tree: `<ProjectRoot>/windows/bin/x64/ffmpeg.exe`
  /// 4. System PATH fallback
  static Future<String?> resolveFfmpegPath() async {
    if (kIsWeb) return null;
    return _resolveBinary('ffmpeg.exe');
  }

  /// Resolves the directory containing `ffmpeg.exe` for use with `--ffmpeg-location`.
  static Future<String?> resolveFfmpegDirectory() async {
    if (kIsWeb) return null;
    final ffmpegPath = await resolveFfmpegPath();
    if (ffmpegPath != null) {
      return p.dirname(ffmpegPath);
    }
    return null;
  }

  /// Resolves argument string for `--js-runtimes` in yt-dlp.
  /// Checks for system `node` or bundled `qjs.exe` to unlock full HD formats.
  static Future<String?> resolveJsRuntimeArg() async {
    if (kIsWeb) return null;

    try {
      final nodeResult = await Process.run('node', ['-v'], runInShell: true);
      if (nodeResult.exitCode == 0) {
        return 'node';
      }
    } catch (_) {
      // Node not found in PATH
    }

    final qjsPath = await _resolveBinary('qjs.exe');
    if (qjsPath != null) {
      return 'quickjs:$qjsPath';
    }

    return null;
  }

  /// Resolves the user-accessible Windows Downloads directory.
  ///
  /// Uses [path_provider]'s `getDownloadsDirectory()` dynamically, with fallback
  /// to `%USERPROFILE%\Downloads` or the active working directory if needed.
  static Future<String> resolveDownloadsDirectory() async {
    if (kIsWeb) return 'Downloads';

    try {
      final dir = await getDownloadsDirectory();
      if (dir != null && await dir.exists()) {
        return dir.path;
      }
    } catch (_) {
      // Ignore and fallback to environment variable
    }

    try {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final downloadsDir = Directory(p.join(userProfile, 'Downloads'));
        if (await downloadsDir.exists()) {
          return downloadsDir.path;
        }
      }
      return Directory.current.path;
    } catch (_) {
      return 'Downloads';
    }
  }

  /// Internal candidate locator for executable binaries on Windows.
  static Future<String?> _resolveBinary(String binaryName) async {
    if (kIsWeb) return null;

    final candidates = <String>[];

    // 1. Check relative to the running application executable (Release / Packaged bundle)
    try {
      final appExecutable = Platform.resolvedExecutable;
      final appDir = p.dirname(appExecutable);
      candidates.add(p.join(appDir, 'bin', binaryName));
      candidates.add(p.join(appDir, binaryName));
    } catch (_) {
      // Platform.resolvedExecutable may not be available in all test runners
    }

    // 2. Check development workspace directories (relative to current working dir)
    try {
      final cwd = Directory.current.path;
      candidates.add(p.join(cwd, 'windows', 'bin', 'x64', binaryName));
      candidates.add(p.join(cwd, 'bin', 'x64', binaryName));
      candidates.add(p.join(cwd, 'bin', binaryName));
    } catch (_) {
      // Ignore
    }

    // 3. Search candidate list
    for (final candidate in candidates) {
      try {
        final file = File(candidate);
        if (await file.exists()) {
          return p.canonicalize(file.path);
        }
      } catch (_) {
        // Ignore
      }
    }

    // 4. Fallback to searching the system PATH
    try {
      final pathEnv = Platform.environment['PATH'];
      if (pathEnv != null) {
        final paths = pathEnv.split(';');
        for (final dir in paths) {
          if (dir.trim().isEmpty) continue;
          final candidate = p.join(dir.trim(), binaryName);
          if (await File(candidate).exists()) {
            return p.canonicalize(candidate);
          }
        }
      }
    } catch (_) {
      // Ignore
    }

    return null;
  }
}
