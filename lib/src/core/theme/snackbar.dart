import 'package:budgly/src/core/theme/material_theme.dart';
import 'package:flutter/material.dart';

enum SnackBarType { error, success, info }

extension SnackBarTypeStyles on SnackBarType {
  Color backgroundColor(BuildContext context) {
    final theme = Theme.of(context);
    return switch (this) {
      SnackBarType.error => theme.colorScheme.errorContainer,
      SnackBarType.success => theme.brightness == Brightness.light
          ? MaterialTheme.success.light.color
          : MaterialTheme.success.dark.color,
      SnackBarType.info => theme.colorScheme.tertiaryContainer,
    };
  }

  Color textColor(BuildContext context) {
    final theme = Theme.of(context);
    return switch (this) {
      SnackBarType.error => theme.colorScheme.onErrorContainer,
      SnackBarType.success => theme.colorScheme.onPrimary,
      SnackBarType.info => theme.colorScheme.onTertiaryContainer,
    };
  }

  IconData get icon => switch (this) {
    SnackBarType.error => Icons.error_outline_rounded,
    SnackBarType.success => Icons.check_circle_outline_rounded,
    SnackBarType.info => Icons.info_outline_rounded,
  };
}

void showAppSnackBar(
  BuildContext context, {
  required String message,
  required SnackBarType type,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: const Duration(seconds: 3),
      elevation: 0,
      showCloseIcon: true,
      content: _SnackBarContent(message: message, type: type),
    ),
  );
}

class _SnackBarContent extends StatelessWidget {
  final String message;
  final SnackBarType type;

  const _SnackBarContent({required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    final textColor = type.textColor(context);

    return Center(
      child: Container(
        padding: const EdgeInsets.all(8).copyWith(left: 16, right: 8),
        decoration: BoxDecoration(
          color: type.backgroundColor(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          spacing: 8,
          children: [
            Icon(type.icon, color: textColor, size: 20),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: textColor),
                textAlign: TextAlign.start,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close_rounded, size: 20),
              color: textColor,
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ],
        ),
      ),
    );
  }
}
