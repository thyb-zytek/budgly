import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/pages/undebited_expenses/view_model.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/action_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UndebitedExpenseCard extends StatelessWidget {
  final UndebitedExpensesViewModel viewModel;
  final ExpenseOccurrence occurrence;

  const UndebitedExpenseCard({
    super.key,
    required this.viewModel,
    required this.occurrence,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final locale = viewModel.localeName;
    final current = viewModel.currentPeriod;
    final origin =
        Period.fromDate(occurrence.sourceDate ?? occurrence.date);
    final removing = viewModel.isRemoving(occurrence);
    final selected = viewModel.isSelected(occurrence);
    final busy = viewModel.isBusy(occurrence);

    return AnimatedSize(
      duration: UndebitedExpensesViewModel.removalDuration,
      curve: Curves.easeOut,
      child: removing
          ? const SizedBox.shrink()
          : GestureDetector(
              onLongPress: viewModel.isInteractive
                  ? () => viewModel.enterSelection(occurrence)
                  : null,
              onTap: viewModel.isInteractive
                  ? () => viewModel.isSelectionMode
                      ? viewModel.toggleSelection(occurrence)
                      : null
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: const EdgeInsets.only(bottom: BudglySpacing.sm),
                padding: const EdgeInsets.all(BudglySpacing.md),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BudglyRadius.large,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withValues(alpha: .3),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: BudglySpacing.xs,
                  children: [
                    Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 120),
                          child: selected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  key: const ValueKey('selected'),
                                  color: theme.colorScheme.primary,
                                )
                              : const Icon(
                                  Icons.receipt_long_rounded,
                                  key: ValueKey('normal'),
                                ),
                        ),
                        const SizedBox(width: BudglySpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              Text(
                                occurrence.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                DateFormat.yMMMMd(locale)
                                    .format(occurrence.date),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatCurrency(
                            amount: occurrence.amount,
                            currencyCode: viewModel.currencyCode,
                            localeName: locale,
                            decimalPlaces: viewModel.amountDecimalPlaces,
                            forceDecimal: true,
                          ),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (!viewModel.isSelectionMode) ...[
                      UndebitedActionButton(
                        type: ButtonType.primary,
                        icon: const Icon(Icons.schedule_send_rounded),
                        label: tr.carryToCurrentPeriod(
                          current.label(locale),
                        ),
                        busy: busy,
                        minHeight: 52,
                        onPressed: () =>
                            viewModel.carryToCurrentPeriod(occurrence),
                      ),
                      UndebitedActionButton(
                        type: ButtonType.tertiary,
                        icon: const Icon(Icons.history_rounded),
                        label: tr.debitOnOriginalPeriod(
                          origin.label(locale),
                        ),
                        busy: busy,
                        minHeight: 48,
                        onPressed: () =>
                            viewModel.debitOnOriginalPeriod(occurrence),
                      ),
                      UndebitedActionButton(
                        type: ButtonType.success,
                        icon: const Icon(Icons.check_circle_outline),
                        label: tr.debitOnCurrentPeriod(
                          current.label(locale),
                        ),
                        busy: busy,
                        minHeight: 48,
                        onPressed: () =>
                            viewModel.debitOnCurrentPeriod(occurrence),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}