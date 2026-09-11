enum VideoQuality {
  best(
    label: 'Best Available',
    subtitle: 'Up to 4K / 1080p',
    shortLabel: 'Best',
    height: null,
  ),
  p1080(
    label: '1080p',
    subtitle: 'Full HD',
    shortLabel: '1080p',
    height: 1080,
  ),
  p720(
    label: '720p',
    subtitle: 'High Definition',
    shortLabel: '720p',
    height: 720,
  ),
  p480(
    label: '480p',
    subtitle: 'Standard Definition',
    shortLabel: '480p',
    height: 480,
  ),
  p360(
    label: '360p',
    subtitle: 'Data Saver',
    shortLabel: '360p',
    height: 360,
  );

  const VideoQuality({
    required this.label,
    required this.subtitle,
    required this.shortLabel,
    required this.height,
  });

  final String label;
  final String subtitle;
  final String shortLabel;
  final int? height;

  String get ytDlpFormatString {
    if (height == null) {
      return 'bv+ba/b';
    }
    return 'bv[height<=$height]+ba/b[height<=$height]/b';
  }
}

enum AudioQuality {
  /// Best available audio — selects opus ~160 kbps when available, m4a otherwise.
  /// Note: 320 kbps is not a native YouTube stream. This picks the highest bitrate
  /// available without re-encoding, which is typically 128–165 kbps.
  k320(
    label: 'Best Available',
    subtitle: '~128–165 kbps (Opus/M4A)',
    shortLabel: 'Best',
    qualityValue: 'high',
  ),

  /// Native AAC stream at ~128 kbps. Always available, zero FFmpeg processing.
  /// Recommended default: fastest download, smallest file, transparent quality.
  k192(
    label: 'Native M4A',
    subtitle: '~128 kbps AAC (fastest)',
    shortLabel: '~128k',
    qualityValue: 'mid',
  ),

  /// Low-bitrate M4A mobile stream (~48 kbps). Use for data-saving.
  k128(
    label: 'Data Saver',
    subtitle: '~48 kbps AAC',
    shortLabel: '~48k',
    qualityValue: 'low',
  );

  const AudioQuality({
    required this.label,
    required this.subtitle,
    required this.shortLabel,
    required this.qualityValue,
  });

  final String label;
  final String subtitle;
  final String shortLabel;
  final String qualityValue;
}
