import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

/// Core palette extracted and refined from the Budgly app icon.
///
/// The icon is a navy-blue disc with cyan highlights, so the palette anchors
/// on the navy background (`primary`) and uses the logo's blue and cyan tones
/// as supporting accents. Each role exposes its light accent (`X`), the pale
/// light container (`XLight`), the accent used in dark mode (`XDark`) and the
/// deepest tone of the family (`XDeep`) used for containers in dark mode and
/// ink text on the pale containers. The palette keeps the icon's visual
/// hierarchy while using slightly more controlled tones for UI surfaces and
/// text so the application remains comfortable to use for long sessions.
abstract final class BudglyPalette {
  // Primary — the navy-blue background of the icon.
  static const primary = Color(0xFF0E2148);
  static const primaryLight = Color(0xFFD6E4FF);
  static const primaryDark = Color(0xFF5FD5E5);
  static const primaryDeep = Color(0xFF08142E);

  // Secondary — the icon's bright blue detail.
  static const secondary = Color(0xFF124185);
  static const secondaryLight = Color(0xFFC8E4FF);
  static const secondaryDark = Color(0xFF9CC8F5);
  static const secondaryDeep = Color(0xFF0F3A75);

  // Tertiary — the icon's cyan highlight, deepened for light-mode contrast.
  static const tertiary = Color(0xFF116D86);
  static const tertiaryLight = Color(0xFFC4EFF6);
  static const tertiaryDark = Color(0xFF7DE1EA);
  static const tertiaryDeep = Color(0xFF0D5B77);

  // Success — keeps the same green family in both modes.
  static const success = Color(0xFF168A4A);
  static const successLight = Color(0xFFD5F4E2);
  static const successDark = Color(0xFF65E39A);
  static const successDeep = Color(0xFF075C31);

  // Semantic error red — intentionally close to the warm red family while
  // remaining immediately distinguishable from the blue brand colors.
  static const error = Color(0xFFB3263A);
  static const errorLight = Color(0xFFFFD9DE);
  static const errorDark = Color(0xFFFFB1BF);
  static const errorDeep = Color(0xFF8D1224);

  // Neutral cold-blue family derived from the icon's near-black navy canvas.
  static const lightCanvas = Color(0xFFF5FAFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const darkCanvas = Color(0xFF010316);
  static const darkSurface = Color(0xFF07102A);
}

abstract final class BudglySpacing {
  static double get xxs => 2.0.w;
  static double get xs => 4.0.w;
  static double get sm => 8.0.w;
  static double get md => 12.0.w;
  static double get lg => 16.0.w;
  static double get xl => 24.0.w;
  static double get xxl => 32.0.w;
}

abstract final class BudglyRadius {
  static const sm = Radius.circular(8);
  static const md = Radius.circular(12);
  static const lg = Radius.circular(16);
  static const xl = Radius.circular(20);

  static const small = BorderRadius.all(sm);
  static const medium = BorderRadius.all(md);
  static const large = BorderRadius.all(lg);
  static const extraLarge = BorderRadius.all(xl);
}

abstract final class BudglyButtonDimensions {
  static EdgeInsets get normalPadding => EdgeInsets.symmetric(
    horizontal: BudglySpacing.xl,
    vertical: BudglySpacing.lg,
  );
  static EdgeInsets get densePadding => EdgeInsets.symmetric(
    horizontal: BudglySpacing.lg,
    vertical: BudglySpacing.sm,
  );
}

abstract final class BudglyComponentStyles {
  static EdgeInsets get cardPadding => EdgeInsets.fromLTRB(
    BudglySpacing.lg,
    BudglySpacing.md,
    BudglySpacing.sm,
    BudglySpacing.md,
  );

  static double get fabSize => 64.w;
  static double get fabIconSize => 48.w;
}
