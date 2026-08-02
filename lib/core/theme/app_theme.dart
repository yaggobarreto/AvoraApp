import 'package:flutter/material.dart';

/// True-dark theme (near-black, not navy-tinted) with image-forward cards
/// for movie content and the brand's purple-to-teal gradient reserved for
/// pill-shaped primary buttons — modeled after dark, poster-driven mobile
/// UIs (IMDb, Pliability) instead of flat color-block surfaces.
class AppTheme {
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF17171F);
  static const surfaceHigh = Color(0xFF1F1F29);
  static const brandPurple = Color(0xFF722C91);
  static const brandTeal = Color(0xFF47C1CE);
  static const onSurface = Color(0xFFF2F2F5);
  static const onSurfaceMuted = Color(0xFFA0A0AC);

  static const primaryGradient = LinearGradient(
    colors: [brandPurple, brandTeal],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Dark scrim used behind text overlaid on poster/backdrop images, so
  /// titles stay readable regardless of the image underneath.
  static const posterScrim = LinearGradient(
    colors: [Colors.transparent, Color(0xE6000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.4, 1.0],
  );

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandPurple,
      brightness: Brightness.dark,
    ).copyWith(
      primary: brandPurple,
      secondary: brandTeal,
      surface: surface,
      onSurface: onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: onSurface),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: onSurface),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: onSurface),
        bodyMedium: TextStyle(color: onSurfaceMuted),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: onSurface,
        iconColor: onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        labelStyle: const TextStyle(color: onSurfaceMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandTeal, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: brandPurple.withValues(alpha: 0.4),
      ),
    );
  }
}
