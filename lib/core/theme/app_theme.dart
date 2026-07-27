import 'package:flutter/material.dart';

/// Colors sampled directly from the Avora logo (navy background, purple to
/// teal gradient wordmark).
class AppTheme {
  static const navyBackground = Color(0xFF0A092A);
  static const navySurface = Color(0xFF16173A);
  static const brandPurple = Color(0xFF722C91);
  static const brandTeal = Color(0xFF47C1CE);

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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: brandPurple),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navySurface,
        indicatorColor: brandPurple.withValues(alpha: 0.4),
      ),
    );
  }
}
