import 'package:flutter/material.dart';

enum DownloadFormat {
  mp4(
    label: 'MP4',
    title: 'MP4 Video',
    subtitle: 'Video & Audio (up to 4K)',
    badge: 'BEST QUALITY',
    extension: 'mp4',
    icon: Icons.movie_creation_outlined,
  ),
  mp3(
    label: 'MP3',
    title: 'MP3 Audio',
    subtitle: 'Pristine 320kbps stream',
    badge: 'AUDIO ONLY',
    extension: 'mp3',
    icon: Icons.headphones_rounded,
  );

  const DownloadFormat({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.extension,
    required this.icon,
  });

  final String label;
  final String title;
  final String subtitle;
  final String badge;
  final String extension;
  final IconData icon;
}
