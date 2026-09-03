import '../../downloader/models/download_format.dart';
import '../../downloader/models/download_item.dart';

enum LibraryFolderType {
  playlist,
  unorganized,
  videos,
}

/// Represents a grouped collection of media items within the Downloads Library.
class LibraryFolder {
  final String name;
  final LibraryFolderType folderType;
  final List<DownloadItem> items;

  const LibraryFolder({
    required this.name,
    required this.folderType,
    required this.items,
  });

  bool get isUnorganized => folderType == LibraryFolderType.unorganized;
  bool get isVideos => folderType == LibraryFolderType.videos;
  bool get isPlaylist => folderType == LibraryFolderType.playlist;

  int get count => items.length;

  int get audioCount =>
      items.where((i) => i.format == DownloadFormat.mp3).length;

  int get videoCount =>
      items.where((i) => i.format == DownloadFormat.mp4).length;

  int get totalSizeBytes =>
      items.fold(0, (sum, i) => sum + (i.fileSizeBytes ?? 0));

  String get formattedTotalSize {
    if (totalSizeBytes <= 0) return '';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var size = totalSizeBytes.toDouble();
    var suffixIndex = 0;
    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }

  /// Up to 4 distinct thumbnail URLs from items in this folder for building a cover collage.
  List<String> get previewThumbnailUrls {
    final list = <String>[];
    for (final item in items) {
      final thumb = item.effectiveThumbnailUrl;
      if (thumb != null && thumb.isNotEmpty && !list.contains(thumb)) {
        list.add(thumb);
        if (list.length == 4) break;
      }
    }
    return list;
  }

  DateTime get latestTimestamp {
    if (items.isEmpty) return DateTime.now();
    var latest = items.first.timestamp;
    for (final item in items) {
      if (item.timestamp.isAfter(latest)) {
        latest = item.timestamp;
      }
    }
    return latest;
  }
}
