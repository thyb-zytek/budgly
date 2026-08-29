import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

Future<void> showExpenseQuickActionsSheet(
  BuildContext context, {
  required VoidCallback? onEdit,
  required VoidCallback onDelete,
}) {
  return showAppBottomSheet(
    context,
    useRootNavigator: true,
    builder: (context) => ExpenseQuickActionsSheet(
      onEdit: onEdit,
      onDelete: onDelete,
    ),
  );
}

class ExpenseQuickActionsSheet extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  const ExpenseQuickActionsSheet({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final edit = onEdit;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(BudglySpacing.lg, BudglySpacing.xs, BudglySpacing.lg, BudglySpacing.lg),
        child: Row(
          spacing: 12,
          children: [
            if (edit != null)
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
              padding: BudglyButtonDimensions.densePadding,
            ),
                  onPressed: () {
                    Navigator.pop(context);
                    edit();
                  },
                  child: Text(tr.edit),
                ),
              ),
            Expanded(
              child: FilledButton(
                style: ButtonType.error.filledStyle(theme, dense: true),
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                child: Text(tr.delete),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
