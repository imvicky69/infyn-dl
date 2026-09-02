class AvailableFormat {
  const AvailableFormat({
    required this.formatId,
    required this.resolutionLabel,
    required this.height,
    required this.totalSizeBytes,
    required this.formattedSize,
  });

  final String formatId;
  final String resolutionLabel; // e.g. '1080p', '720p', '480p', '360p'
  final int height;
  final int totalSizeBytes;
  final String formattedSize; // e.g. '67.2 MB'
}

class VideoMetadata {
  const VideoMetadata({
    required this.id,
    required this.title,
    this.uploader,
    this.thumbnailUrl,
    required this.durationSeconds,
    required this.videoFormats,
    this.audioSizeBytes,
  });

  final String id;
  final String title;
  final String? uploader;
  final String? thumbnailUrl;
  final int durationSeconds;
  final List<AvailableFormat> videoFormats;
  final int? audioSizeBytes;

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String formattedAudioSize(String qualityValue) {
    if (durationSeconds <= 0) {
      return audioSizeBytes != null ? _formatBytes(audioSizeBytes!) : '~8 MB';
    }
    // Estimate based on bitrate and duration
    // 320 kbps = 40 KB/s, 192 kbps = 24 KB/s, 128 kbps = 16 KB/s
    final kbps = qualityValue == '0' ? 320 : (qualityValue == '2' ? 192 : 128);
    final bytes = (kbps * 1000 / 8 * durationSeconds).round();
    return _formatBytes(bytes);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  static VideoMetadata fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final title = json['title'] as String? ?? 'Untitled Video';
    final uploader = json['uploader'] as String? ?? json['channel'] as String?;
    final thumbnail = json['thumbnail'] as String?;
    final duration = (json['duration'] as num?)?.toInt() ?? 0;

    // Find best audio size
    int bestAudioSize = 0;
    final rawFormats = json['formats'] as List<dynamic>? ?? [];

    for (final f in rawFormats) {
      if (f is! Map<String, dynamic>) continue;
      final vcodec = f['vcodec'] as String?;
      final acodec = f['acodec'] as String?;
      if ((vcodec == null || vcodec == 'none') && acodec != null && acodec != 'none') {
        final size = (f['filesize'] as num?)?.toInt() ?? (f['filesize_approx'] as num?)?.toInt() ?? 0;
        if (size > bestAudioSize) {
          bestAudioSize = size;
        }
      }
    }

    // Fallback audio estimate if unknown: ~128kbps * duration
    if (bestAudioSize == 0 && duration > 0) {
      bestAudioSize = (128 * 1000 / 8 * duration).round();
    }

    // Map unique video resolutions by height
    final heightMap = <int, AvailableFormat>{};

    for (final f in rawFormats) {
      if (f is! Map<String, dynamic>) continue;
      final height = (f['height'] as num?)?.toInt();
      final vcodec = f['vcodec'] as String?;
      final acodec = f['acodec'] as String?;
      if (height == null || height < 144) continue;
      if (vcodec == 'none') continue; // audio only

      final formatId = f['format_id'] as String? ?? '$height';
      final videoSize = (f['filesize'] as num?)?.toInt() ?? (f['filesize_approx'] as num?)?.toInt() ?? 0;
      final formatHasAudio = acodec != null && acodec != 'none';
      final totalSize = videoSize > 0
          ? (formatHasAudio ? videoSize : (videoSize + bestAudioSize))
          : 0;

      // Prefer formats with higher size or known size
      if (!heightMap.containsKey(height) || (totalSize > heightMap[height]!.totalSizeBytes)) {
        heightMap[height] = AvailableFormat(
          formatId: formatId,
          resolutionLabel: '${height}p',
          height: height,
          totalSizeBytes: totalSize,
          formattedSize: totalSize > 0 ? _formatBytes(totalSize) : '',
        );
      }
    }

    // Sort heights descending (e.g. 2160, 1440, 1080, 720, 480, 360, 240)
    final sortedHeights = heightMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final videoFormats = sortedHeights.map((h) => heightMap[h]!).toList();

    return VideoMetadata(
      id: id,
      title: title,
      uploader: uploader,
      thumbnailUrl: thumbnail,
      durationSeconds: duration,
      videoFormats: videoFormats,
      audioSizeBytes: bestAudioSize > 0 ? bestAudioSize : null,
    );
  }
}
