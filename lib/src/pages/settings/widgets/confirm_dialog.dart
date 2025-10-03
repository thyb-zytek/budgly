import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:flutter/material.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(title, style: theme.textTheme.titleSmall),
      content: Text(content, style: theme.textTheme.bodyMedium),
      actions: [
        BudglyButton(
          text: tr.cancel,
          dense: true,
          type: ButtonType.error,
          onPressed: () {
            if (onCancel != null) {
              onCancel!();
            }
            Navigator.pop(context);
          },
        ),
        BudglyButton(
          text: tr.validate,
          dense: true,
          type: ButtonType.primary,
          onPressed: () {
            onConfirm();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
