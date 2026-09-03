import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static bool isDark = false;

  // Modern Monochrome Palette (Vercel / Apple Minimalist, adapts to Dark Mode)
  static Color get background =>
      isDark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA);
  static Color get surface =>
      isDark ? const Color(0xFF141416) : const Color(0xFFFFFFFF);
  static Color get surfaceElevated =>
      isDark ? const Color(0xFF1F1F23) : const Color(0xFFF4F4F5);
  static Color get surfaceBorder =>
      isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
  static Color get surfaceBorderActive =>
      isDark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B);

  // Modern Monochromatic Accents
  static Color get primary =>
      isDark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B);
  static Color get onPrimary =>
      isDark ? const Color(0xFF09090B) : const Color(0xFFFFFFFF);
  static Color get primaryEnd =>
      isDark ? const Color(0xFFD4D4D8) : const Color(0xFF27272A);
  static Color get primaryGlow =>
      isDark ? const Color(0x33FFFFFF) : const Color(0x14000000);
  static Color get primaryContainer =>
      isDark ? const Color(0xFF1F1F23) : const Color(0xFFF4F4F5);

  static LinearGradient get primaryGradient => isDark
      ? const LinearGradient(
          colors: [Color(0xFFFAFAFA), Color(0xFFE4E4E7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFF09090B), Color(0xFF27272A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

  // Typography
  static Color get textPrimary =>
      isDark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B);
  static Color get textSecondary =>
      isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
  static Color get textMuted =>
      isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA);

  // Status Accents
  static const Color success = Color(0xFF10B981);
  static Color get successBg =>
      isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
  static const Color error = Color(0xFFEF4444);
  static Color get errorBg =>
      isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
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
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF09090B),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFF4F4F5),
        onPrimaryContainer: Color(0xFF09090B),
        secondary: Color(0xFF27272A),
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFF4F4F5),
        onSecondaryContainer: Color(0xFF09090B),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF09090B),
        surfaceContainerHighest: Color(0xFFF4F4F5),
        onSurfaceVariant: Color(0xFF71717A),
        outline: Color(0xFFE4E4E7),
        outlineVariant: Color(0xFFE4E4E7),
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          color: const Color(0xFF09090B),
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: const Color(0xFF09090B),
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: const Color(0xFF09090B),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: const Color(0xFF09090B),
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: const Color(0xFF71717A),
          height: 1.5,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: const Color(0xFF71717A),
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
          side: const BorderSide(color: Color(0xFFE4E4E7), width: 1),
        ),
        color: const Color(0xFFFFFFFF),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF09090B),
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFAFAFA),
        onPrimary: Color(0xFF09090B),
        primaryContainer: Color(0xFF1F1F23),
        onPrimaryContainer: Color(0xFFFAFAFA),
        secondary: Color(0xFFD4D4D8),
        onSecondary: Color(0xFF09090B),
        secondaryContainer: Color(0xFF27272A),
        onSecondaryContainer: Color(0xFFFAFAFA),
        surface: Color(0xFF141416),
        onSurface: Color(0xFFFAFAFA),
        surfaceContainerHighest: Color(0xFF1F1F23),
        onSurfaceVariant: Color(0xFFA1A1AA),
        outline: Color(0xFF27272A),
        outlineVariant: Color(0xFF3F3F46),
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          color: const Color(0xFFFAFAFA),
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: const Color(0xFFFAFAFA),
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: const Color(0xFFFAFAFA),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: const Color(0xFFFAFAFA),
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: const Color(0xFFA1A1AA),
          height: 1.5,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: const Color(0xFFA1A1AA),
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
          side: const BorderSide(color: Color(0xFF27272A), width: 1),
        ),
        color: const Color(0xFF141416),
      ),
    );
  }
}
