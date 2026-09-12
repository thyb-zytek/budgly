import 'dart:async';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/pages/undebited_expenses/view_model.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/action_button.dart';
import 'package:flutter/material.dart';

/// Bottom-pinned block carrying the three bulk actions for the current
/// selection.
///
/// Outside of selection mode, the same three actions are available per card
/// via swipe gestures instead of buttons (see [UndebitedExpenseCard]); a
/// bulk selection can't be expressed as a single swipe, so it keeps this
/// dedicated button bar. Selection bookkeeping (count and select/deselect
/// scope) lives in the strip above the list instead.
class UndebitedBulkActionBar extends StatelessWidget {
  final UndebitedExpensesViewModel viewModel;

  const UndebitedBulkActionBar({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final period = viewModel.currentPeriod;
    final locale = viewModel.localeName;

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (viewModel.isProcessing)
            const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BudglySpacing.lg,
              BudglySpacing.sm,
              BudglySpacing.lg,
              BudglySpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: BudglySpacing.sm,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UndebitedActionButton(
                  type: ButtonType.primary,
                  icon: const Icon(Icons.schedule_send_rounded),
                  label: tr.carryToCurrentPeriod(period.label(locale)),
                  busy: viewModel.isProcessing,
                  minHeight: 52,
                  onPressed: () =>
                      unawaited(viewModel.carrySelectedToCurrentPeriod()),
                ),
                // A bulk selection can span several distinct original periods
                // at once (e.g. via "select all" across grouped sections), so
                // this deliberately does not name a single period the way the
                // per-item button does — that would misrepresent every item
                // whose own original period differs from whichever one is
                // shown.
                UndebitedActionButton(
                  type: ButtonType.tertiary,
                  icon: const Icon(Icons.history_rounded),
                  label: tr.debitOnOriginalPeriodBulk,
                  busy: viewModel.isProcessing,
                  minHeight: 48,
                  onPressed: () =>
                      unawaited(viewModel.debitSelectedOnOriginalPeriod()),
                ),
                UndebitedActionButton(
                  type: ButtonType.success,
                  icon: const Icon(Icons.check_circle_outline),
                  label: tr.debitOnCurrentPeriod(period.label(locale)),
                  busy: viewModel.isProcessing,
                  minHeight: 48,
                  onPressed: () =>
                      unawaited(viewModel.debitSelectedOnCurrentPeriod()),
                ),
              ],
            ),
          ),
          // Hard separation between the sticky actions and the list above.
          const Divider(height: 1, thickness: 1),
        ],
      ),
    );
  }
}
