/// The original identity (near black, amber text, red heart), rebuilt on
/// Material 3 with bundled fonts: Inter for the interface, Lora for quotes.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // The first version used Colors.black87, amber[600], amber[300] and red.
  static const background = Color(0xFF141414);
  static const surface = Color(0xFF1C1B19);
  static const surfaceHigh = Color(0xFF262421);
  static const amber = Color(0xFFFFB300); // amber[600]
  static const amberSoft = Color(0xFFFFD54F); // amber[300]
  static const heart = Color(0xFFEF5350);
  static const text = Color(
    0xFFF2ECE0,
  ); // warm white, easier on the eyes than pure white
  static const textMuted = Color(0xFFB9B1A3);
}

TextStyle _w(TextStyle? style, int weight) =>
    (style ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      // The bundled fonts are variable fonts: set the weight axis explicitly.
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );

/// The serif style for quote text.
TextStyle quoteStyle(BuildContext context, {double? size}) {
  final base = Theme.of(context).textTheme.titleLarge!;
  return _w(base, 450).copyWith(
    fontFamily: 'Lora',
    fontStyle: FontStyle.italic,
    fontSize: size ?? 20,
    height: 1.45,
    color: AppColors.amber,
  );
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.amber,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.amber,
        onPrimary: Colors.black,
        secondary: AppColors.amberSoft,
        onSecondary: Colors.black,
        tertiary: AppColors.heart,
        surface: AppColors.background,
        onSurface: AppColors.text,
        onSurfaceVariant: AppColors.textMuted,
        surfaceContainerLow: AppColors.surface,
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: AppColors.surfaceHigh,
        surfaceContainerHighest: AppColors.surfaceHigh,
        outlineVariant: const Color(0xFF3A3631),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
  );
  final t = base.textTheme;
  final text = t.copyWith(
    headlineSmall: _w(t.headlineSmall, 600),
    titleLarge: _w(t.titleLarge, 600),
    titleMedium: _w(t.titleMedium, 600),
    titleSmall: _w(t.titleSmall, 600),
    bodyLarge: _w(t.bodyLarge, 400).copyWith(height: 1.5),
    bodyMedium: _w(t.bodyMedium, 400).copyWith(height: 1.5),
    labelLarge: _w(t.labelLarge, 600),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: _w(text.titleLarge, 500).copyWith(
        fontFamily: 'Lora',
        fontStyle: FontStyle.italic,
        color: AppColors.amber,
      ),
      iconTheme: const IconThemeData(color: AppColors.amber),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF2E2B27)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.amber.withValues(alpha: 0.18),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.amber
              : AppColors.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => _w(text.labelMedium, 600).copyWith(
          color: states.contains(WidgetState.selected)
              ? AppColors.amber
              : AppColors.textMuted,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF2E2B27)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF2E2B27)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        textStyle: _w(text.labelLarge, 600).copyWith(fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
        foregroundColor: AppColors.amber,
        side: const BorderSide(color: Color(0xFF4A443C)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: Color(0xFF3A3631)),
      labelStyle: _w(text.labelLarge, 500).copyWith(color: AppColors.amberSoft),
      shape: const StadiumBorder(),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
