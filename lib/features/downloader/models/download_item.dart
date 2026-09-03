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
  final String? playlistUrl;

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
    this.playlistUrl,
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
        'playlistUrl': playlistUrl,
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
      playlistUrl: json['playlistUrl'] as String?,
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

  /// Returns the stored thumbnail URL, or automatically resolves YouTube thumbnail art from [url].
  String? get effectiveThumbnailUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl;
    }
    return extractYoutubeThumbnail(url);
  }

  /// Helper to extract standard YouTube thumbnail image URL from common video URLs.
  static String? extractYoutubeThumbnail(String url) {
    if (url.isEmpty) return null;
    final clean = url.trim();
    final regExp = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(clean);
    if (match != null && match.groupCount >= 1) {
      final videoId = match.group(1);
      return 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
    }
    if (RegExp(r'^[\w-]{11}$').hasMatch(clean)) {
      return 'https://img.youtube.com/vi/$clean/mqdefault.jpg';
    }
    return null;
  }

  DownloadItem copyWith({
    String? id,
    String? title,
    String? url,
    String? filePath,
    DownloadFormat? format,
    String? quality,
    String? thumbnailUrl,
    int? fileSizeBytes,
    DateTime? timestamp,
    String? playlistName,
    String? playlistUrl,
    bool clearPlaylist = false,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      quality: quality ?? this.quality,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      timestamp: timestamp ?? this.timestamp,
      playlistName: clearPlaylist ? null : (playlistName ?? this.playlistName),
      playlistUrl: clearPlaylist ? null : (playlistUrl ?? this.playlistUrl),
    );
  }
}
