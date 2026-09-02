import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/downloader/screens/downloader_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MediaDownloaderApp());
}

class MediaDownloaderApp extends StatelessWidget {
  const MediaDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'infyn-yt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const DownloaderScreen(),
    );
  }
}
