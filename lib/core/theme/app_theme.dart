import 'package:flutter/material.dart';

/// Colors sampled directly from the Avora logo (navy background, purple to
/// teal gradient wordmark). Content cards are white/near-white on top of the
/// dark background — like a Netflix-style dark shell with light content
/// cards — rather than filling everything with solid purple.
class AppTheme {
  static const navyBackground = Color(0xFF0A092A);
  static const navySurface = Color(0xFF16173A);
  static const brandPurple = Color(0xFF722C91);
  static const brandTeal = Color(0xFF47C1CE);
  static const cardSurface = Color(0xFFFAFAFC);
  static const cardOnSurface = Color(0xFF1A1B2E);

  static const primaryGradient = LinearGradient(
    colors: [brandPurple, brandTeal],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandPurple,
      brightness: Brightness.dark,
    ).copyWith(
      primary: brandPurple,
      secondary: brandTeal,
      surface: navySurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: navyBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: navyBackground,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: cardOnSurface,
        iconColor: cardOnSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navySurface,
        indicatorColor: brandPurple.withValues(alpha: 0.4),
      ),
    );
  }
}
