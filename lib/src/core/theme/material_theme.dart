import 'package:flutter/material.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

class MaterialTheme {
  const MaterialTheme();

  static TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 48.sp,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      height: 1.1,
    ),
    displayMedium: TextStyle(
      fontSize: 40.sp,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.1,
    ),
    displaySmall: TextStyle(
      fontSize: 32.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.2,
    ),

    headlineLarge: TextStyle(
      fontSize: 28.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 24.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.3,
    ),
    headlineSmall: TextStyle(
      fontSize: 20.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.3,
    ),

    titleLarge: TextStyle(
      fontSize: 18.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontSize: 16.sp,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontSize: 14.sp,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    ),

    bodyLarge: TextStyle(
      fontSize: 16.sp,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14.sp,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.3,
      height: 1.5,
    ),

    labelLarge: TextStyle(
      fontSize: 14.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontSize: 11.sp,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.4,
    ),
  );

  // Surface colors are intentionally derived from the icon's near-black navy
  // canvas instead of a neutral blue-grey family.
  static const Color _lightCanvas = BudglyPalette.lightCanvas;
  static const Color _lightSurface = BudglyPalette.lightSurface;
  static const Color _darkCanvas = BudglyPalette.darkCanvas;
  static const Color _darkSurface = BudglyPalette.darkSurface;

  static Color _tonalSurface(Color surface, Color tint, Color recede, double strength) {
    final blendColor = strength >= 0 ? tint : recede;
    final alpha = (strength.abs() * 255).round().clamp(0, 255);
    return Color.alphaBlend(blendColor.withAlpha(alpha), surface);
  }

  static ColorScheme lightScheme() {
    const primary = BudglyPalette.primary;
    const tint = primary;
    const recede = Colors.white;

    Color tonal(double strength) =>
        _tonalSurface(_lightSurface, tint, recede, strength);

    return ColorScheme(
      brightness: Brightness.light,

      // Navy: the logo's background colour is the app's primary anchor.
      primary: primary,
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: BudglyPalette.primaryLight,
      onPrimaryContainer: BudglyPalette.primaryDeep,
      inversePrimary: BudglyPalette.primaryDark,

      // Bright blue extracted from the icon's blue detail, slightly toned
      // down for sustained use in controls and data visualisation.
      secondary: BudglyPalette.secondary,
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: BudglyPalette.secondaryLight,
      onSecondaryContainer: BudglyPalette.secondaryDeep,

      // Deepened cyan: reserved for highlights, budgets, objectives and
      // premium cues, echoing the icon's highlight.
      tertiary: BudglyPalette.tertiary,
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: BudglyPalette.tertiaryLight,
      onTertiaryContainer: BudglyPalette.tertiaryDeep,

      error: BudglyPalette.error,
      onError: const Color(0xFFFFFFFF),
      errorContainer: BudglyPalette.errorLight,
      onErrorContainer: BudglyPalette.errorDeep,

      surface: _lightSurface,
      onSurface: const Color(0xFF172033),
      onSurfaceVariant: const Color(0xFF526078),
      inverseSurface: const Color(0xFF172033),
      onInverseSurface: const Color(0xFFF5F8FF),

      surfaceContainerLowest: _lightSurface,
      surfaceContainerLow: tonal(0.025),
      surfaceContainer: tonal(0.05),
      surfaceContainerHigh: tonal(0.08),
      surfaceContainerHighest: tonal(0.11),

      outline: const Color(0xFF9AA8BC),
      outlineVariant: const Color(0xFFD9E2ED),
      shadow: Colors.transparent,
      scrim: const Color(0x66000000),
      surfaceTint: Colors.transparent,
    );
  }

  static ColorScheme darkScheme() {
    const primary = BudglyPalette.primaryDark;
    const tint = primary;
    const recede = Colors.black;

    Color tonal(double strength) =>
        _tonalSurface(_darkSurface, tint, recede, strength);

    return ColorScheme(
      brightness: Brightness.dark,

      // The logo's cyan highlight pops against the near-black navy surfaces
      // while keeping the icon's identity readable in dark mode.
      primary: primary,
      onPrimary: BudglyPalette.primaryDeep,
      primaryContainer: const Color(0xFF17335F),
      onPrimaryContainer: BudglyPalette.primaryLight,
      inversePrimary: BudglyPalette.primary,

      // Softer blue echoing the icon's blue detail without becoming
      // aggressive on a dark interface.
      secondary: BudglyPalette.secondaryDark,
      onSecondary: BudglyPalette.secondaryDeep,
      secondaryContainer: const Color(0xFF1B4A86),
      onSecondaryContainer: BudglyPalette.secondaryLight,

      // Sky-cyan keeps the icon's highlight visible in dark mode.
      tertiary: BudglyPalette.tertiaryDark,
      onTertiary: BudglyPalette.tertiaryDeep,
      tertiaryContainer: BudglyPalette.tertiaryDeep,
      onTertiaryContainer: BudglyPalette.tertiaryLight,

      error: BudglyPalette.errorDark,
      onError: const Color(0xFF650012),
      errorContainer: BudglyPalette.errorDeep,
      onErrorContainer: BudglyPalette.errorLight,

      surface: _darkSurface,
      onSurface: const Color(0xFFE3EDF8),
      onSurfaceVariant: const Color(0xFFB6C3D6),
      inverseSurface: const Color(0xFFE7EDF8),
      onInverseSurface: _darkCanvas,

      surfaceContainerLowest: _darkCanvas,
      surfaceContainerLow: tonal(0.025),
      surfaceContainer: tonal(0.05),
      surfaceContainerHigh: tonal(0.08),
      surfaceContainerHighest: tonal(0.11),

      outline: const Color(0xFF8295AC),
      outlineVariant: const Color(0xFF24364D),
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

    final buttonTextStyle = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    );

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
          borderRadius: BudglyRadius.large,
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
          padding: BudglyButtonDimensions.normalPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BudglyRadius.medium,
            side: BorderSide(color: border, width: 1),
          ),
          textStyle: buttonTextStyle,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: BudglyButtonDimensions.normalPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BudglyRadius.medium,
            side: BorderSide(color: border, width: 1),
          ),
          textStyle: buttonTextStyle,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: colorScheme.primary,
          padding: BudglyButtonDimensions.normalPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BudglyRadius.medium,
            side: BorderSide(color: borderStrong, width: 1),
          ),
          textStyle: buttonTextStyle,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BudglyRadius.large,
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
          borderRadius: BudglyRadius.medium,
          borderSide: BorderSide(color: borderStrong, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BudglyRadius.medium,
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BudglyRadius.medium,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BudglyRadius.medium,
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BudglyRadius.medium,
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
              borderRadius: BudglyRadius.medium,
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
          borderRadius: BudglyRadius.extraLarge,
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
    seed: BudglyPalette.success,
    value: BudglyPalette.success,
    light: ColorFamily(
      color: BudglyPalette.success,
      onColor: Color(0xFFFFFFFF),
    ),
    dark: ColorFamily(
      color: BudglyPalette.successDark,
      onColor: Color(0xFF00391B),
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
