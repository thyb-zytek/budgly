import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';

class SnackBarMessage extends SnackBar {
  final String message;
  final SnackBarType type;

  SnackBarMessage({super.key, required this.message, required this.type})
    : super(
        content: _SnackBarMessageContent(message: message, type: type),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 3),
        elevation: 0,
        showCloseIcon: true,
      );
}

class _SnackBarMessageContent extends StatelessWidget {
  final String message;
  final SnackBarType type;

  const _SnackBarMessageContent({required this.message, required this.type});

  Color _getBackgroundColor(BuildContext context) {
    switch (type) {
      case SnackBarType.error:
        return Theme.of(context).colorScheme.errorContainer;
      case SnackBarType.success:
        return Theme.of(context).brightness == Brightness.light
            ? MaterialTheme.success.light.color
            : MaterialTheme.success.dark.color;
      case SnackBarType.info:
        return Theme.of(context).colorScheme.tertiaryContainer;
    }
  }

  Color _getTextColor(BuildContext context) {
    switch (type) {
      case SnackBarType.error:
        return Theme.of(context).colorScheme.onErrorContainer;
      case SnackBarType.success:
        return Theme.of(context).colorScheme.onPrimary;
      case SnackBarType.info:
        return Theme.of(context).colorScheme.onTertiaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8).copyWith(left: 16, right: 8),
        decoration: BoxDecoration(
          color: _getBackgroundColor(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          spacing: 8,
          children: [
            Icon(_getIcon(), color: _getTextColor(context), size: 20),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _getTextColor(context)),
                textAlign: TextAlign.start,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.close_rounded, size: 20),
              color: _getTextColor(context),
              onPressed:
                  () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case SnackBarType.error:
        return Icons.error_outline_rounded;
      case SnackBarType.success:
        return Icons.check_circle_outline_rounded;
      case SnackBarType.info:
        return Icons.info_outline_rounded;
    }
  }
}

enum SnackBarType { error, success, info }
