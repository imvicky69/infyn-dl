import 'download_format.dart';

/// Represents a completed download record stored in local persistent history.
class DownloadItem {
  final String id;
  final String title;
  final String url;
  final String filePath;
  final DownloadFormat format;
  final String quality;
  final String? thumbnailUrl;
  final int? fileSizeBytes;
  final DateTime timestamp;
  final String? playlistName;

  const DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.filePath,
    required this.format,
    required this.quality,
    this.thumbnailUrl,
    this.fileSizeBytes,
    required this.timestamp,
    this.playlistName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'filePath': filePath,
        'format': format.name,
        'quality': quality,
        'thumbnailUrl': thumbnailUrl,
        'fileSizeBytes': fileSizeBytes,
        'timestamp': timestamp.toIso8601String(),
        'playlistName': playlistName,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Media',
      url: json['url'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      format: (json['format'] as String?) == 'mp3'
          ? DownloadFormat.mp3
          : DownloadFormat.mp4,
      quality: json['quality'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileSizeBytes: json['fileSizeBytes'] as int?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      playlistName: json['playlistName'] as String?,
    );
  }

  String get formattedFileSize {
    if (fileSizeBytes == null || fileSizeBytes! <= 0) return '';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var size = fileSizeBytes!.toDouble();
    var suffixIndex = 0;
    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }
}
