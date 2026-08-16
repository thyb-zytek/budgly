import 'package:budgly/src/core/theme/material_theme.dart';
import 'package:flutter/material.dart';

enum ButtonType {
  primary,
  secondary,
  tertiary,
  success,
  error,
  neutral,
  neutralVariant,
  outlined,
  iconDefault,
  iconOnPrimary,
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
      ButtonType.neutral => ButtonColors(
        background: scheme.outline,
        foreground: scheme.onInverseSurface,
        icon: scheme.outlineVariant,
      ),
      ButtonType.neutralVariant => ButtonColors(
        background: scheme.outlineVariant,
        foreground: scheme.onSurfaceVariant,
        icon: scheme.outlineVariant,
      ),
      ButtonType.outlined => ButtonColors(
        background: scheme.surface,
        foreground: scheme.onSurfaceVariant,
        icon: scheme.onSurfaceVariant,
      ),
      ButtonType.iconDefault => ButtonColors(
        background: scheme.primary,
        foreground: scheme.onPrimary,
        icon: scheme.inverseSurface,
      ),
      ButtonType.iconOnPrimary => ButtonColors(
        background: scheme.primary,
        foreground: scheme.onPrimary,
        icon: scheme.onPrimaryContainer,
      ),
      ButtonType.primary => ButtonColors(
        background: scheme.primary,
        foreground: scheme.onPrimary,
        icon: scheme.primary,
      ),
    };
  }

  ButtonStyle filledStyle(ThemeData theme, {bool dense = false}) {
    final c = colors(theme);
    return FilledButton.styleFrom(
      backgroundColor: c.background,
      foregroundColor: c.foreground,
      padding: EdgeInsets.symmetric(
        vertical: dense ? 8 : 16,
        horizontal: dense ? 16 : 24,
      ),
      iconSize: dense ? 20 : 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dense ? 8 : 10),
        side: this == ButtonType.outlined
            ? BorderSide(color: c.foreground, width: 1)
            : BorderSide.none,
      ),
    );
  }

  TextStyle? labelStyle(ThemeData theme, {bool dense = false}) {
    final c = colors(theme);
    return dense
        ? theme.textTheme.titleMedium?.copyWith(color: c.foreground)
        : theme.textTheme.titleLarge?.copyWith(color: c.foreground);
  }

  ButtonStyle iconButtonStyle(ThemeData theme, {bool filled = false}) {
    if (!filled) return IconButton.styleFrom();
    final c = colors(theme);
    return IconButton.styleFrom(backgroundColor: c.background);
  }

  Color iconButtonColor(ThemeData theme, {bool filled = false}) {
    final c = colors(theme);
    return filled ? c.foreground : c.icon;
  }
}
