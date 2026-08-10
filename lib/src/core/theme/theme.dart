import "package:flutter/material.dart";

class MaterialTheme {
  const MaterialTheme();

  static TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Saira',
      fontSize: 57,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.2,
    ),

    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.3,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.3,
    ),

    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),

    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.5,
    ),

    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
    ),
  );

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF2B4C7E),
      // Sophisticated blue - more subdued
      onPrimary: Color(0xFFFFFFFF),
      inversePrimary: Color(0xFF6B8AB3),
      // Lighter blue for inverse
      secondary: Color(0xFF6B5B7E),
      // Muted purple - elegant
      onSecondary: Color(0xFFFFFFFF),
      tertiary: Color(0xFF4A7B8C),
      // Muted teal - sophisticated
      onTertiary: Color(0xFFFFFFFF),
      error: Color(0xFFD32F2F),
      // Refined red - less aggressive
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFEBEE),
      onErrorContainer: Color(0xFFB71C1C),
      surface: Color(0xFFFAFAFA),
      // Very light gray - clean
      inverseSurface: Color(0xFF1A1A1A),
      surfaceContainer: Color(0xFFFFFFFF),
      // Pure white cards
      surfaceContainerHigh: Color(0xFFF5F5F5),
      // Subtle gray for elevated elements
      onSurface: Color(0xFF1A1A1A),
      // Dark gray text - better than pure black
      onSurfaceVariant: Color(0xFF5A5A5A),
      // Muted text color
      onInverseSurface: Color(0xFFFAFAFA),
      surfaceTint: Color(0xFF2B4C7E),
      outline: Color(0xFFC0C0C0),
      // Subtle borders
      outlineVariant: Color(0xFFB8B8B8),
      // Even more subtle borders
      shadow: Color(0x1A000000),
      // Very subtle shadows
      scrim: Color(0x80000000),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF6B8AB3),
      // Muted blue for dark mode
      onPrimary: Color(0xFF0D1B2A),
      // Dark background for primary
      inversePrimary: Color(0xFF2B4C7E),
      // Original primary for inverse
      secondary: Color(0xFF8B7B9E),
      // Lightened purple for dark mode
      onSecondary: Color(0xFF0D1B2A),
      tertiary: Color(0xFF7A9BAC),
      // Lightened teal for dark mode
      onTertiary: Color(0xFF0D1B2A),
      error: Color(0xFFEF5350),
      // Refined red for dark mode
      onError: Color(0xFF0D1B2A),
      errorContainer: Color(0xFFB71C1C),
      onErrorContainer: Color(0xFFFFEBEE),
      surface: Color(0xFF0D1B2A),
      // Deep blue-gray - sophisticated dark
      inverseSurface: Color(0xFFFAFAFA),
      surfaceContainer: Color(0xFF1A2633),
      // Card backgrounds - subtle contrast
      surfaceContainerHigh: Color(0xFF263545),
      // Elevated containers - more contrast
      onSurface: Color(0xFFE0E0E0),
      // Light gray text for readability
      onSurfaceVariant: Color(0xFFA0A0A0),
      // Muted text color
      onInverseSurface: Color(0xFF0D1B2A),
      surfaceTint: Color(0xFF6B8AB3),
      outline: Color(0xFF3A4A5A),
      // Subtle borders for dark mode
      outlineVariant: Color(0xFF4A5A6A),
      // Even more subtle borders
      shadow: Color(0x40000000),
      // Shadow for dark mode
      scrim: Color(0x80000000),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    fontFamily: "Saira",
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
    textTheme: textTheme,
    // Elevated buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    // Text buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    // Outlined buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(
          color: colorScheme.outline,
          width: 1,
        ),
      ),
    ),
    // Input decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.error,
          width: 1,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    // Card theme
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: colorScheme.surfaceContainer,
    ),
    // AppBar theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
    ),
    // Divider theme
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
  );

  /// Success
  static const success = ExtendedColor(
    seed: Color(0xFF4CAF50),
    value: Color(0xFF4CAF50),
    light: ColorFamily(color: Color(0xFF4CAF50), onColor: Color(0xFFFFFFFF)),
    dark: ColorFamily(color: Color(0xFF66BB6A), onColor: Color(0xFF0D1B2A)),
  );

  List<ExtendedColor> get extendedColors => [success];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily dark;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.dark,
  });
}

class ColorFamily {
  const ColorFamily({required this.color, required this.onColor});

  final Color color;
  final Color onColor;
}
