import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

Future<void> showExpenseQuickActionsSheet(
  BuildContext context, {
  required VoidCallback? onEdit,
  required VoidCallback? onDelete,
  VoidCallback? onMarkPending,
}) {
  return showAppBottomSheet(
    context,
    useRootNavigator: true,
    builder: (context) => ExpenseQuickActionsSheet(
      onEdit: onEdit,
      onDelete: onDelete,
      onMarkPending: onMarkPending,
    ),
  );
}

class ExpenseQuickActionsSheet extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkPending;

  const ExpenseQuickActionsSheet({
    super.key,
    required this.onEdit,
    required this.onDelete,
    this.onMarkPending,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final edit = onEdit;
    final delete = onDelete;
    final markPending = onMarkPending;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          BudglySpacing.lg,
          BudglySpacing.xs,
          BudglySpacing.lg,
          BudglySpacing.lg,
        ),
        child: Row(
          spacing: 12,
          children: [
            // A debited expense can no longer be edited or deleted: it can
            // only be put back on hold, so that is the sole action offered.
            if (markPending != null)
              Expanded(
                child: FilledButton(
                  style: ButtonType.secondary.filledStyle(theme, dense: true),
                  onPressed: () {
                    Navigator.pop(context);
                    markPending();
                  },
                  child: Text(tr.expenseMarkedAsPending),
                ),
              ),
            if (edit != null)
              Expanded(
                child: FilledButton(
                  style: ButtonType.primary.filledStyle(theme, dense: true),
                  onPressed: () {
                    Navigator.pop(context);
                    edit();
                  },
                  child: Text(tr.edit),
                ),
              ),
            if (delete != null)
              Expanded(
                child: FilledButton(
                  style: ButtonType.error.filledStyle(theme, dense: true),
                  onPressed: () {
                    Navigator.pop(context);
                    delete();
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
