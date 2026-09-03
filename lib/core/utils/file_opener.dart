import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cross-platform utility to open files in native system media players or default viewers.
class FileOpener {
  FileOpener._();

  static const MethodChannel _androidChannel =
      MethodChannel('com.example.media_downloader/downloader_methods');

  /// Opens the file at [filePath] using the platform's default application.
  static Future<bool> open(String filePath) async {
    if (filePath.isEmpty) return false;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _androidChannel.invokeMethod<bool>(
          'openFile',
          {'path': filePath},
        );
        return result ?? false;
      } catch (e) {
        debugPrint('Android openFile error: $e');
        return false;
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        await Process.run('cmd.exe', ['/c', 'start', '', filePath]);
        return true;
      } catch (e) {
        debugPrint('Windows open file error: $e');
        return false;
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        await Process.run('open', [filePath]);
        return true;
      } catch (e) {
        debugPrint('macOS open file error: $e');
        return false;
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      try {
        await Process.run('xdg-open', [filePath]);
        return true;
      } catch (e) {
        debugPrint('Linux open file error: $e');
        return false;
      }
    }

    return false;
  }
}
