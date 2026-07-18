import 'package:flutter/material.dart';

/// Oneiro's visual identity.
///
/// A deep-indigo seed over quiet night-sky surfaces: bright and calm by day,
/// starlit after dark. All colors are original to Oneiro.
abstract final class AppTheme {
  /// Seed color for both schemes — a deep, slightly violet indigo.
  static const Color seedColor = Color(0xFF4A55A8);

  /// Accent used for lucid-dream markers (a small moonlit amber).
  static const Color lucidAccent = Color(0xFFF5C542);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    return _base(
      scheme,
    ).copyWith(scaffoldBackgroundColor: const Color(0xFFF6F6FB));
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF16182A),
          surfaceContainerLowest: const Color(0xFF0F1120),
          surfaceContainerLow: const Color(0xFF14162A),
          surfaceContainer: const Color(0xFF1B1E33),
          surfaceContainerHigh: const Color(0xFF22263E),
        );
    return _base(
      scheme,
    ).copyWith(scaffoldBackgroundColor: const Color(0xFF0F1120));
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: const CardThemeData(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
