import "package:flutter/material.dart";

class MaterialTheme {
  const MaterialTheme();

  static TextTheme textTheme = const TextTheme(
    displayLarge: TextStyle(
      fontFamily: "Saira",
      fontSize: 48,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      height: 1.1,
    ),
    displayMedium: TextStyle(
      fontFamily: "Saira",
      fontSize: 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.1,
    ),
    displaySmall: TextStyle(
      fontFamily: "Saira",
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.2,
    ),

    headlineLarge: TextStyle(
      fontFamily: "Saira",
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontFamily: "Saira",
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.3,
    ),
    headlineSmall: TextStyle(
      fontFamily: "Saira",
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.3,
    ),

    titleLarge: TextStyle(
      fontFamily: "Saira",
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontFamily: "Saira",
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontFamily: "Saira",
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),

    bodyLarge: TextStyle(
      fontFamily: "Saira",
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: "Saira",
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: "Saira",
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.3,
      height: 1.5,
    ),

    labelLarge: TextStyle(
      fontFamily: "Saira",
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      fontFamily: "Saira",
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontFamily: "Saira",
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.4,
    ),
  );

  static const Color _lightCanvas = Color(0xFFF5F5F7);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _darkCanvas = Color(0xFF0C0A14);
  static const Color _darkSurface = Color(0xFF1E1E2A);

  static Color _tonalSurface(Color surface, Color tint, Color recede, double strength) {
    final blendColor = strength >= 0 ? tint : recede;
    final alpha = (strength.abs() * 255).round().clamp(0, 255);
    return Color.alphaBlend(blendColor.withAlpha(alpha), surface);
  }

  static ColorScheme lightScheme() {
    const primary = Color(0xFF2C2665);
    const tint = primary;
    const recede = Colors.white;

    Color tonal(double strength) => _tonalSurface(_lightSurface, tint, recede, strength);

    return ColorScheme(
      brightness: Brightness.light,

      primary: primary,
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFE1DEFF),
      onPrimaryContainer: const Color(0xFF17104E),
      inversePrimary: const Color(0xFFC2BFFF),

      secondary: const Color(0xFF5E5A75),
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: const Color(0xFFE4E1F1),
      onSecondaryContainer: const Color(0xFF1C192B),

      tertiary: const Color(0xFF71717A),
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: const Color(0xFFF4F4F5),
      onTertiaryContainer: const Color(0xFF27272A),

      error: const Color(0xFFE11D48),
      onError: const Color(0xFFFFFFFF),
      errorContainer: const Color(0xFFFFE4E6),
      onErrorContainer: const Color(0xFF9F1239),

      surface: _lightSurface,
      onSurface: const Color(0xFF12101C),
      onSurfaceVariant: const Color(0xFF5E5A75),
      inverseSurface: const Color(0xFF1C192B),
      onInverseSurface: _lightCanvas,

      surfaceContainerLowest: _lightSurface,
      surfaceContainerLow: _lightSurface,
      surfaceContainer: tonal(0.05),
      surfaceContainerHigh: tonal(0.08),
      surfaceContainerHighest: tonal(0.11),

      outline: const Color(0xFFD3CEDB),
      outlineVariant: const Color(0xFFE8E5EE),
      shadow: Colors.transparent,
      scrim: const Color(0x66000000),
      surfaceTint: Colors.transparent,
    );
  }

  static ColorScheme darkScheme() {
    const primary = Color(0xFFC2BFFF);
    const tint = primary;
    const recede = Colors.black;

    Color tonal(double strength) => _tonalSurface(_darkSurface, tint, recede, strength);

    return ColorScheme(
      brightness: Brightness.dark,

      primary: primary,
      onPrimary: const Color(0xFF17104E),
      primaryContainer: const Color(0xFF2C2665),
      onPrimaryContainer: const Color(0xFFE1DEFF),
      inversePrimary: const Color(0xFF2C2665),

      secondary: const Color(0xFFAAA5C0),
      onSecondary: const Color(0xFF1C192B),
      secondaryContainer: const Color(0xFF46425D),
      onSecondaryContainer: const Color(0xFFE4E1F1),

      tertiary: const Color(0xFFA1A1AA),
      onTertiary: const Color(0xFF09090B),
      tertiaryContainer: const Color(0xFF27272A),
      onTertiaryContainer: const Color(0xFFE4E4E7),

      error: const Color(0xFFFB7185),
      onError: const Color(0xFF4C0519),
      errorContainer: const Color(0xFF881337),
      onErrorContainer: const Color(0xFFFFE4E6),

      surface: _darkSurface,
      onSurface: const Color(0xFFF9F9FB),
      onSurfaceVariant: const Color(0xFFAAA5C0),
      inverseSurface: const Color(0xFFF9F9FB),
      onInverseSurface: _darkCanvas,

      surfaceContainerLowest: _darkCanvas,
      surfaceContainerLow: _darkSurface,
      surfaceContainer: tonal(0.05),
      surfaceContainerHigh: tonal(0.08),
      surfaceContainerHighest: tonal(0.11),

      outline: const Color(0xFF4C4761),
      outlineVariant: const Color(0xFF2E2756),
      shadow: Colors.transparent,
      scrim: const Color(0x80000000),
      surfaceTint: Colors.transparent,
    );
  }

  ThemeData theme(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    final canvas = isLight ? _lightCanvas : _darkCanvas;
    final surface = isLight ? _lightSurface : _darkSurface;
    final border = colorScheme.outlineVariant.withValues(alpha: 0.5);
    final borderStrong = colorScheme.outline.withValues(alpha: 0.6);

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      fontFamily: "Saira",
      textTheme: textTheme.apply(
        fontFamily: "Saira",
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: Border(
          bottom: BorderSide(color: border, width: 1),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: border, width: 1),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: border, width: 1),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderStrong, width: 1),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
        sizeConstraints: const BoxConstraints.tightFor(
          width: 56,
          height: 56,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        alignLabelWithHint: true,
        errorMaxLines: 3,
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderStrong, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: surface,
        elevation: 0,
        selectedItemColor: colorScheme.primary,
        selectedIconTheme: IconThemeData(
          size: 24,
          color: colorScheme.primary,
        ),
        unselectedIconTheme: IconThemeData(
          size: 24,
          color: colorScheme.onSurfaceVariant,
        ),
        selectedLabelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.labelMedium,
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: colorScheme.primary,
              size: 24,
            );
          }
          return IconThemeData(
            color: colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: border, width: 1),
            ),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border, width: 1),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: border, width: 1),
        ),
      ),
    );
  }

  ThemeData light() => theme(lightScheme());
  ThemeData dark() => theme(darkScheme());

  static const success = ExtendedColor(
    seed: Color(0xFF10B981),
    value: Color(0xFF10B981),
    light: ColorFamily(
      color: Color(0xFF10B981),
      onColor: Color(0xFFFFFFFF),
    ),
    dark: ColorFamily(
      color: Color(0xFF34D399),
      onColor: Color(0xFF022C22),
    ),
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
