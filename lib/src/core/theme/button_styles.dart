import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/theme/material_theme.dart';
import 'package:flutter/material.dart';

/// Semantic button variants used across the app.
///
/// [primary], [secondary] and [tertiary] mirror the app's brand hierarchy
/// and cover the vast majority of actions (submit, alternate choice,
/// low-emphasis action...). [success] and [error] carry a fixed meaning
/// regardless of hierarchy, and [neutralVariant] is a low-emphasis
/// fallback for actions that shouldn't compete visually with anything
/// (e.g. next to a user-customized account or category color).
///
/// Use [filledStyle], [outlinedStyle] or [textButtonStyle] with the same
/// [ButtonType] to keep filled/outlined/text buttons visually consistent
/// wherever they appear.
enum ButtonType {
  primary,
  secondary,
  tertiary,
  success,
  error,
  neutralVariant,
}

class ButtonColors {
  final Color background;
  final Color foreground;
  final Color icon;

  const ButtonColors({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}

extension ButtonTypeStyles on ButtonType {
  ButtonColors colors(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return switch (this) {
      ButtonType.primary => ButtonColors(
          background: scheme.primary,
          foreground: scheme.onPrimary,
          icon: scheme.primary,
        ),
      ButtonType.secondary => ButtonColors(
          background: scheme.secondary,
          foreground: scheme.onSecondary,
          icon: scheme.secondary,
        ),
      ButtonType.tertiary => ButtonColors(
          background: scheme.tertiary,
          foreground: scheme.onTertiary,
          icon: scheme.tertiary,
        ),
      ButtonType.success => ButtonColors(
          background: isLight
              ? MaterialTheme.success.light.color
              : MaterialTheme.success.dark.color,
          foreground: isLight
              ? MaterialTheme.success.light.onColor
              : MaterialTheme.success.dark.onColor,
          icon: isLight
              ? MaterialTheme.success.light.color
              : MaterialTheme.success.dark.color,
        ),
      ButtonType.error => ButtonColors(
          background: scheme.error,
          foreground: scheme.onError,
          icon: scheme.error,
        ),
      ButtonType.neutralVariant => ButtonColors(
          background: scheme.outlineVariant,
          foreground: scheme.onSurfaceVariant,
          icon: scheme.outlineVariant,
        ),
    };
  }

  ButtonStyle filledStyle(ThemeData theme, {bool dense = false}) {
    final c = colors(theme);
    return FilledButton.styleFrom(
      backgroundColor: c.background,
      foregroundColor: c.foreground,
      padding: dense
          ? BudglyButtonDimensions.densePadding
          : BudglyButtonDimensions.normalPadding,
      iconSize: dense ? 20 : 24,
    );
  }

  /// Outlined variant of this button type: same accent color as
  /// [filledStyle] but used as the text/icon/border color instead of a
  /// solid fill. Meant for secondary-emphasis actions sitting next to a
  /// [filledStyle] button (e.g. "cancel" next to "confirm").
  ButtonStyle outlinedStyle(ThemeData theme, {bool dense = false}) {
    final c = colors(theme);
    return OutlinedButton.styleFrom(
      foregroundColor: c.background,
      side: BorderSide(color: c.background.withValues(alpha: 0.5)),
      padding: dense
          ? BudglyButtonDimensions.densePadding
          : BudglyButtonDimensions.normalPadding,
      iconSize: dense ? 20 : 24,
    );
  }

  /// Text-only variant of this button type, for the lowest-emphasis
  /// actions (inline links, dismissive actions in banners or dialogs).
  ButtonStyle textButtonStyle(ThemeData theme, {bool dense = false}) {
    final c = colors(theme);
    return TextButton.styleFrom(
      foregroundColor: c.background,
      padding: dense
          ? BudglyButtonDimensions.densePadding
          : BudglyButtonDimensions.normalPadding,
      iconSize: dense ? 20 : 24,
    );
  }

  /// Filled circular [IconButton] variant of this button type, for
  /// standalone icon actions that need to carry the same semantic color
  /// (e.g. a destructive delete action, or a success/secondary toggle)
  /// as the app's filled/outlined/text buttons.
  ButtonStyle iconFilledStyle(
    ThemeData theme, {
    Size minimumSize = const Size(40, 40),
  }) {
    final c = colors(theme);
    return IconButton.styleFrom(
      backgroundColor: c.background,
      foregroundColor: c.foreground,
      minimumSize: minimumSize,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
