import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';

enum ButtonType {
  primary,
  secondary,
  tertiary,
  success,
  error,
  neutral,
  neutralVariant,
  iconDefault,
}

class TypedButtonStyle {
  ButtonType type;
  ThemeData theme;

  late Color _backgroundColor;
  late Color _textColor;
  late Color _iconColor;

  TypedButtonStyle({required this.type, required this.theme}) {
    switch (type) {
      case ButtonType.success:
        _backgroundColor =
            theme.brightness == Brightness.light
                ? MaterialTheme.success.light.color
                : MaterialTheme.success.dark.color;
        _textColor =
            theme.brightness == Brightness.light
                ? MaterialTheme.success.light.onColor
                : MaterialTheme.success.dark.onColor;
        _iconColor =
            theme.brightness == Brightness.light
                ? MaterialTheme.success.light.color
                : MaterialTheme.success.dark.color;
        ;
        break;
      case ButtonType.error:
        _backgroundColor = theme.colorScheme.error;
        _textColor = theme.colorScheme.onSecondaryContainer;
        _iconColor = theme.colorScheme.error;
        break;
      case ButtonType.secondary:
        _backgroundColor = theme.colorScheme.secondary;
        _textColor = theme.colorScheme.onSecondaryContainer;
        _iconColor = theme.colorScheme.secondary;
        break;
      case ButtonType.tertiary:
        _backgroundColor = theme.colorScheme.tertiary;
        _textColor = theme.colorScheme.onTertiaryContainer;
        _iconColor = theme.colorScheme.tertiary;
        break;
      case ButtonType.neutral:
        _backgroundColor = theme.colorScheme.outline;
        _textColor = theme.colorScheme.onInverseSurface;
        _iconColor = theme.colorScheme.outlineVariant;
        break;
      case ButtonType.neutralVariant:
        _backgroundColor = theme.colorScheme.outlineVariant;
        _textColor = theme.colorScheme.onInverseSurface;
        _iconColor = theme.colorScheme.outlineVariant;
        break;
      case ButtonType.iconDefault:
        _iconColor = theme.colorScheme.outline;
        break;
      default:
        _backgroundColor = theme.colorScheme.primary;
        _textColor = theme.colorScheme.onPrimaryContainer;
        _iconColor = theme.colorScheme.primary;
        break;
    }
  }

  Color get textColor => _textColor;

  Color get backgroundColor => _backgroundColor;

  Color get iconColor => _iconColor;
}
