import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

typedef _GetShortPathNameWNative = Int32 Function(
    Pointer<Utf16> lpszLongPath, Pointer<Utf16> lpszShortPath, Int32 cchBuffer);
typedef _GetShortPathNameWDart = int Function(
    Pointer<Utf16> lpszLongPath, Pointer<Utf16> lpszShortPath, int cchBuffer);

/// Resolves Windows file paths to 8.3 short paths or safe local paths
/// to bypass WinRT MediaPlayer limitations on Unicode and special characters.
class WindowsPathHelper {
  static String getPlayablePath(String filePath) {
    if (!Platform.isWindows) return filePath;

    // 1. Attempt Win32 GetShortPathNameW
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final getShortPathNameW = kernel32.lookupFunction<
          _GetShortPathNameWNative, _GetShortPathNameWDart>('GetShortPathNameW');

      final longPathPtr = filePath.toNativeUtf16();
      final buffer = calloc<Uint16>(1024).cast<Utf16>();
      try {
        final result = getShortPathNameW(longPathPtr, buffer, 1024);
        if (result > 0) {
          final shortPath = buffer.toDartString();
          if (File(shortPath).existsSync()) {
            return shortPath;
          }
        }
      } finally {
        calloc.free(longPathPtr);
        calloc.free(buffer);
      }
    } catch (e) {
      debugPrint('WindowsPathHelper.getShortPathName error: $e');
    }

    // 2. Fallback: Copy to a safe ASCII temporary file if needed
    try {
      final source = File(filePath);
      if (source.existsSync()) {
        final ext = p.extension(filePath).isNotEmpty ? p.extension(filePath) : '.mp3';
        final tempFile = File(p.join(
          Directory.systemTemp.path,
          'infyn_play_${filePath.hashCode.abs()}$ext',
        ));
        if (!tempFile.existsSync() || tempFile.lengthSync() != source.lengthSync()) {
          source.copySync(tempFile.path);
        }
        return tempFile.path;
      }
    } catch (e) {
      debugPrint('WindowsPathHelper temp copy error: $e');
    }

    return filePath;
  }
}
