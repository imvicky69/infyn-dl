import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/download_format.dart';
import '../models/download_item.dart';

/// Persistent cache & history manager for media downloads.
class DownloadHistoryService {
  static const String _cacheFileName = 'downloads_cache.json';

  static DownloadHistoryService? _instance;
  static DownloadHistoryService get instance =>
      _instance ??= DownloadHistoryService._();

  DownloadHistoryService._();

  final List<DownloadItem> _cachedItems = [];
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          _cachedItems.clear();
          for (final item in jsonList) {
            if (item is Map<String, dynamic>) {
              _cachedItems.add(DownloadItem.fromJson(item));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error initializing DownloadHistoryService: $e');
    }
    _isInitialized = true;
  }

  Future<File> _getCacheFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File(p.join(docsDir.path, _cacheFileName));
  }

  Future<void> _persistToDisk() async {
    try {
      final file = await _getCacheFile();
      final jsonList = _cachedItems.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving download history: $e');
    }
  }

  /// Returns all cached downloads sorted by latest first.
  Future<List<DownloadItem>> getHistory() async {
    if (!_isInitialized) await init();
    return List.unmodifiable(_cachedItems..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  }

  /// Adds a completed download item to the persistent history.
  Future<void> addDownload(DownloadItem item) async {
    if (!_isInitialized) await init();
    _cachedItems.removeWhere((existing) => existing.id == item.id);
    _cachedItems.insert(0, item);
    await _persistToDisk();
  }

  /// Deletes a download from history and optionally removes the physical file from disk.
  Future<void> removeDownload(String id, {bool deletePhysicalFile = false}) async {
    if (!_isInitialized) await init();
    final index = _cachedItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _cachedItems[index];
      if (deletePhysicalFile && item.filePath.isNotEmpty) {
        try {
          final file = File(item.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting file ${item.filePath}: $e');
        }
      }
      _cachedItems.removeAt(index);
      await _persistToDisk();
    }
  }

  /// Clears all items from the history cache.
  Future<void> clearHistory() async {
    if (!_isInitialized) await init();
    _cachedItems.clear();
    await _persistToDisk();
  }

  /// Determines whether a video/track with the given title and format is already downloaded.
  /// Checks both the persistent history cache and the destination filesystem.
  Future<bool> isAlreadyDownloaded({
    required String title,
    required DownloadFormat format,
    String? targetDirectory,
  }) async {
    if (!_isInitialized) await init();

    final ext = format == DownloadFormat.mp3 ? 'mp3' : 'mp4';
    final cleanTitle = _sanitizeFilename(title).toLowerCase();

    // 1. Check in cached history items
    for (final item in _cachedItems) {
      if (item.format == format) {
        final itemCleanTitle = _sanitizeFilename(item.title).toLowerCase();
        if (itemCleanTitle == cleanTitle) {
          if (item.filePath.isNotEmpty) {
            try {
              if (await File(item.filePath).exists()) {
                return true;
              }
            } catch (_) {}
          }
        }
      }
    }

    // 2. Check destination directory on disk if provided
    if (targetDirectory != null && targetDirectory.isNotEmpty) {
      try {
        final dir = Directory(targetDirectory);
        if (await dir.exists()) {
          final expectedFile = File(p.join(targetDirectory, '$cleanTitle.$ext'));
          if (await expectedFile.exists()) {
            return true;
          }

          // Scan directory files for matching title
          final entities = await dir.list().toList();
          for (final entity in entities) {
            if (entity is File) {
              final fileName = p.basenameWithoutExtension(entity.path).toLowerCase();
              final fileExt = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
              if (fileExt == ext && (fileName == cleanTitle || fileName.contains(cleanTitle))) {
                return true;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking destination directory for duplicate: $e');
      }
    }

    return false;
  }

  static String _sanitizeFilename(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  }
}
