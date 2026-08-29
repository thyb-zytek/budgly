import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/theme/material_theme.dart';
import 'package:flutter/material.dart';

enum ButtonType {
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
}
