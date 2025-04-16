import "package:flutter/material.dart";

class MaterialTheme {
  const MaterialTheme();

  static TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w900),
    displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w800),
    displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),

    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),

    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),

    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),

    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
  );

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff0057DA),
      // primary
      onPrimary: Color(0xFFE5E9EF),
      inversePrimary: Color(0xff80b6f8),
      // Text Color on primary
      secondary: Color(0xff9836d3),
      // Secondary Color
      onSecondary: Color(0xFFE5E9EF),
      // Text Color on secondary
      tertiary: Color(0xff40BCD8),
      // tertiary
      onTertiary: Color(0xff101011),
      // Text Color on tertiary
      error: Color(0xffE84343),
      // Error Color
      onError: Color(0xff101011),
      // Text Color on error
      surface: Color(0xFFE5E9EF),
      inverseSurface: Color(0xff0F1011),
      // Background Color
      surfaceContainer: Color(0xFFF4F8FF),
      // Card Background Color (soft white)
      surfaceContainerHigh: Color(0xFFFAFCFF),
      onSurface: Color(0xff101011),
      // Default Text Color
      onSurfaceVariant: Color(0xff626972),
      // Softer hint text color
      surfaceTint: Color(0xff1e1e35),
      // Harmonized elevation/shadow color
      outline: Color(0xff16191D),
      // Updated hint text/divider
      outlineVariant: Color(0xff626972),
      // Softer hint text divider variant
      shadow: Color(0xff000000),
      // Shadow
      scrim: Color(0xff000000), // Color of blocked component on modal show
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff80b6f8),
      // Lighter shade of your primary for dark mode
      onPrimary: Color(0xff0F1011),
      // Text on primary
      inversePrimary: Color(0xff0057DA),
      // Original primary, used as inverse
      secondary: Color(0xffC07BEE),
      // Lightened secondary for dark background
      onSecondary: Color(0xff0F1011),
      tertiary: Color(0xff8DE6F5),
      // Lightened tertiary
      onTertiary: Color(0xff0F1011),
      error: Color(0xffFF6B6B),
      // Brightened error for visibility
      onError: Color(0xff0F1011),
      surface: Color(0xff101113),
      // Main background
      inverseSurface: Color(0xFFF4F8FF),
      // Light background used inversely
      surfaceContainer: Color(0xff1A1B1D),
      // Card backgrounds
      surfaceContainerHigh: Color(0xff222326),
      // Elevated containers
      onSurface: Color(0xFFE5E9EF),
      // Primary readable text
      onSurfaceVariant: Color(0xffA9B0B8),
      // Softer hint text
      surfaceTint: Color(0xff80b6f8),
      // Harmonized elevation/shadow tint
      outline: Color(0xff44484D),
      // Divider/hint border
      outlineVariant: Color(0xff6D737A),
      // Softer divider
      shadow: Color(0xff000000),
      // Shadow for dark mode
      scrim: Color(0xff000000), // For modal overlays
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
  );

  /// Success
  static const success = ExtendedColor(
    seed: Color(0xff5ECA57),
    value: Color(0xff5ECA57),
    light: ColorFamily(color: Color(0xff5ECA57), onColor: Color(0xff101011)),
    dark: ColorFamily(color: Color(0xff85F08A), onColor: Color(0xff101011)),
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
