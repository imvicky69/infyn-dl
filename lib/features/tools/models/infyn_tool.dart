import 'package:flutter/material.dart';

enum ToolCategory {
  pdf,
  image,
}

/// Represents an in-browser utility tool provided by infyn.software.
class InfynTool {
  final String id;
  final String title;
  final String description;
  final ToolCategory category;
  final String badge;
  final IconData icon;
  final String url;

  const InfynTool({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.badge,
    required this.icon,
    required this.url,
  });

  static const List<InfynTool> allTools = [
    // PDF Tools
    InfynTool(
      id: 'pdf-to-image',
      title: 'PDF to Image',
      description:
          'Render and export all or selected PDF pages into high-resolution JPG or PNG images.',
      category: ToolCategory.pdf,
      badge: 'High-Res',
      icon: Icons.picture_as_pdf_rounded,
      url: 'https://infyn.software/pdf/pdf-to-image',
    ),
    InfynTool(
      id: 'img-to-pdf',
      title: 'Image to PDF',
      description:
          'Convert and combine single or batch images into a clean, formatted PDF document.',
      category: ToolCategory.pdf,
      badge: 'Batch',
      icon: Icons.collections_rounded,
      url: 'https://infyn.software/image/img-to-pdf',
    ),
    InfynTool(
      id: 'pdf-merger',
      title: 'PDF Merger',
      description:
          'Combine multiple PDF documents into a single file with visual page reordering.',
      category: ToolCategory.pdf,
      badge: 'No Limits',
      icon: Icons.call_merge_rounded,
      url: 'https://infyn.software/pdf/merger',
    ),
    InfynTool(
      id: 'pdf-splitter',
      title: 'PDF Splitter & Extractor',
      description:
          'Extract specific page ranges or split a PDF into separate files with 1-click ZIP download.',
      category: ToolCategory.pdf,
      badge: 'Page Grid',
      icon: Icons.call_split_rounded,
      url: 'https://infyn.software/pdf/splitter',
    ),
    InfynTool(
      id: 'pdf-protector',
      title: 'PDF Password Protector',
      description:
          'Secure sensitive PDF documents with standard AES-256 password encryption right in browser.',
      category: ToolCategory.pdf,
      badge: 'AES-256',
      icon: Icons.lock_rounded,
      url: 'https://infyn.software/pdf/protector',
    ),
    InfynTool(
      id: 'pdf-unlocker',
      title: 'PDF Unlocker',
      description:
          'Safely remove passwords and restrictions from encrypted PDF documents.',
      category: ToolCategory.pdf,
      badge: 'Client-Side',
      icon: Icons.lock_open_rounded,
      url: 'https://infyn.software/pdf/unlocker',
    ),

    // Image Tools
    InfynTool(
      id: 'bg-remover',
      title: 'AI Background Remover',
      description:
          'Generate instant transparent cutouts using in-browser machine learning — zero cloud uploads.',
      category: ToolCategory.image,
      badge: 'In-Browser AI',
      icon: Icons.auto_fix_high_rounded,
      url: 'https://infyn.software/image/bg-remover',
    ),
    InfynTool(
      id: 'image-compressor',
      title: 'Batch Image Compressor',
      description:
          'Drastically reduce image file sizes with customizable quality targets and instant preview.',
      category: ToolCategory.image,
      badge: 'Lossless / Lossy',
      icon: Icons.compress_rounded,
      url: 'https://infyn.software/image/compressor',
    ),
    InfynTool(
      id: 'image-resizer',
      title: 'Image Resizer & Crop',
      description:
          'Resize dimensions, change aspect ratios, and fit photos with blurred canvas padding.',
      category: ToolCategory.image,
      badge: 'Aspect Ratio',
      icon: Icons.crop_rounded,
      url: 'https://infyn.software/image/resizer',
    ),
    InfynTool(
      id: 'image-converter',
      title: 'Universal Image Converter',
      description:
          'Batch convert photos between JPG, PNG, WEBP, AVIF, and HEIC formats.',
      category: ToolCategory.image,
      badge: 'Multi-Format',
      icon: Icons.transform_rounded,
      url: 'https://infyn.software/image/converter',
    ),
    InfynTool(
      id: 'heic-to-jpg',
      title: 'HEIC to JPG Converter',
      description:
          'Seamlessly decode Apple iPhone .heic and .heif photos into universally compatible JPEGs.',
      category: ToolCategory.image,
      badge: 'WASM',
      icon: Icons.photo_library_rounded,
      url: 'https://infyn.software/image/heic-to-jpg',
    ),
    InfynTool(
      id: 'exif-remover',
      title: 'EXIF & Metadata Remover',
      description:
          'Strip GPS coordinates, camera serial numbers, and device metadata from photos before sharing.',
      category: ToolCategory.image,
      badge: 'Privacy',
      icon: Icons.security_rounded,
      url: 'https://infyn.software/image/exif-remover',
    ),
  ];
}
