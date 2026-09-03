import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Modern Monochrome Light Palette (Vercel / Apple Minimalist)
  static const Color background =
      Color(0xFFFAFAFA); // Ultra-clean zinc-50 canvas
  static const Color surface = Color(0xFFFFFFFF); // Crisp white card surface
  static const Color surfaceElevated =
      Color(0xFFF4F4F5); // Neutral zinc-100 container
  static const Color surfaceBorder =
      Color(0xFFE4E4E7); // Subtle zinc-200 border
  static const Color surfaceBorderActive =
      Color(0xFF09090B); // Obsidian active border

  // Modern Monochromatic Accents
  static const Color primary = Color(0xFF09090B); // Deep obsidian black
  static const Color primaryEnd = Color(0xFF27272A); // Charcoal zinc-800
  static const Color primaryGlow =
      Color(0x14000000); // Clean subtle elevation shadow
  static const Color primaryContainer =
      Color(0xFFF4F4F5); // Clean neutral zinc container

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF09090B), Color(0xFF27272A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Typography
  static const Color textPrimary = Color(0xFF09090B); // Crisp obsidian
  static const Color textSecondary = Color(0xFF71717A); // Zinc-500 body
  static const Color textMuted =
      Color(0xFFA1A1AA); // Zinc-400 placeholder/caption

  // Status Accents
  static const Color success =
      Color(0xFF10B981); // Crisp emerald green for success
  static const Color successBg = Color(0xFFECFDF5);
  static const Color error = Color(0xFFEF4444); // Crisp red for errors
  static const Color errorBg = Color(0xFFFEF2F2);
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.primary,
        secondary: AppColors.primaryEnd,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFF4F4F5),
        onSecondaryContainer: AppColors.primary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceElevated,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.surfaceBorder,
        outlineVariant: Color(0xFFE4E4E7),
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
        color: AppColors.surface,
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
