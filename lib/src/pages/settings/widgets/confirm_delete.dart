import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/shared/widgets/buttons/button.dart';
import 'package:budgly/src/shared/widgets/buttons/constants.dart';
import 'package:flutter/material.dart';

class ConfirmDelete extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const ConfirmDelete({
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

    return SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 24,
              children: [
                Text(
                 title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                Text(
                  content,
                  style: theme.textTheme.bodyMedium,
                ),
                Row(
                  spacing: 16,
                  children: [
                    Expanded(
                      child: BudglyButton(
                        onPressed: () => Navigator.pop(context),
                        type: ButtonType.outlined,
                        text: tr.cancel,
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: BudglyButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      dense: true,
                      type: ButtonType.error,
                      text: tr.validate,
                    ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
  }
}
