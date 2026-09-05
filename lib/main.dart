import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/home/screens/main_shell_screen.dart';
import 'features/player/services/liked_songs_service.dart';
import 'features/player/services/media_cache_service.dart';
import 'features/settings/services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init();
  await LikedSongsService.instance.init();
  await MediaCacheService.instance.init();
  runApp(const MediaDownloaderApp());
}

class MediaDownloaderApp extends StatelessWidget {
  const MediaDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService.instance.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Infyn DL',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          builder: (context, child) {
            AppColors.isDark = Theme.of(context).brightness == Brightness.dark;
            return child!;
          },
          home: const MainShellScreen(),
        );
      },
    );
  }
}
