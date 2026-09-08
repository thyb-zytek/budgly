import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/shared/ui/widgets/forms/form_actions.dart';
import 'package:flutter/material.dart';

class ConfirmDelete extends StatelessWidget {
  final String title;
  final String content;
  final Future<void> Function() onConfirm;
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
    final theme = Theme.of(context);

    return SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              left: BudglySpacing.xl,
              right: BudglySpacing.xl,
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
                FormActions(
                  destructiveSubmit: true,
                  dense: true,
                  onCancel: () => Navigator.pop(context),
                  onSubmit: () async {
                    await onConfirm();
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                ),
              ],
            ),
          ),
        );
  }
}

enum RecurringDeleteChoice { single, future }
enum RecurringEditChoice { single, future }

Future<bool?> showConfirmDelete(
  BuildContext context, {
  required String title,
  required String content,
  required Future<void> Function() onConfirm,
}) {
  final theme = Theme.of(context);

  return showAppBottomSheet<bool>(
    context,
    backgroundColor: theme.colorScheme.surface,
    builder: (context) => ConfirmDelete(
      title: title,
      content: content,
      onConfirm: onConfirm,
    ),
  );
}

Future<RecurringDeleteChoice?> showRecurringDeleteOptions(
  BuildContext context, {
  required String expenseName,
  required String dateLabel,
}) {
  final tr = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  return showAppBottomSheet<RecurringDeleteChoice>(
    context,
    backgroundColor: theme.colorScheme.surface,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: BudglySpacing.xl,
          right: BudglySpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              tr.confirmDeleteRecurringExpense(expenseName),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tr.confirmDeleteRecurringExpenseMessage(dateLabel),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: ButtonType.neutralVariant.filledStyle(theme),
                onPressed: () => Navigator.pop(context, RecurringDeleteChoice.single),
                child: Text(tr.deleteSingleOccurrence),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: ButtonType.error.filledStyle(theme),
                onPressed: () => Navigator.pop(context, RecurringDeleteChoice.future),
                child: Text(tr.deleteFutureOccurrences),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr.cancel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


Future<RecurringEditChoice?> showRecurringEditOptions(
  BuildContext context, {
  required String expenseName,
  required String dateLabel,
}) {
  final tr = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  return showAppBottomSheet<RecurringEditChoice>(
    context,
    backgroundColor: theme.colorScheme.surfaceContainer,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: BudglySpacing.xl,
          right: BudglySpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              tr.modifyRecurringExpense(expenseName),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tr.modifyRecurringExpenseMessage(dateLabel),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, RecurringEditChoice.single),
                child: Text(tr.modifyThisOccurrence),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: ButtonType.primary.filledStyle(theme),
                onPressed: () => Navigator.pop(context, RecurringEditChoice.future),
                child: Text(tr.modifyOccurrenceAndFollowing),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr.cancel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
