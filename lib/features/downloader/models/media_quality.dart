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
  k320(
    label: '320 kbps',
    subtitle: 'Pristine Audio',
    shortLabel: '320k',
    qualityValue: '0',
  ),
  k192(
    label: '192 kbps',
    subtitle: 'Standard High',
    shortLabel: '192k',
    qualityValue: '2',
  ),
  k128(
    label: '128 kbps',
    subtitle: 'Compact Size',
    shortLabel: '128k',
    qualityValue: '5',
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
