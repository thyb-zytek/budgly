import 'dart:async';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/pages/undebited_expenses/view_model.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/swipe_action_background.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/swipe_actions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Card for a single undebited occurrence.
///
/// Actions are driven by horizontal swipe rather than buttons:
/// - swiping left immediately debits the occurrence on its original period;
/// - swiping right is deliberately blocked (the card always snaps back) and
///   opens [showUndebitedSwipeActionsSheet], since "report" and "debit now"
///   are two distinct actions that can't be told apart from a single swipe.
///
/// Swipe is disabled while the list is in selection mode: taps there toggle
/// selection instead, and a mid-drag gesture would be ambiguous with that.
class UndebitedExpenseCard extends StatelessWidget {
  final UndebitedExpensesViewModel viewModel;
  final ExpenseOccurrence occurrence;

  /// Called the first time the user interacts with this card (tap,
  /// long-press or swipe attempt), so callers can stop a transient hint
  /// animation once the gesture has been demonstrated for real.
  final VoidCallback? onUserInteracted;

  const UndebitedExpenseCard({
    super.key,
    required this.viewModel,
    required this.occurrence,
    this.onUserInteracted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final locale = viewModel.localeName;
    final current = viewModel.currentPeriod;
    final origin = Period.fromDate(occurrence.sourceDate ?? occurrence.date);
    final removing = viewModel.isRemoving(occurrence);
    final selected = viewModel.isSelected(occurrence);
    final busy = viewModel.isBusy(occurrence);
    final canSwipe = viewModel.isInteractive && !viewModel.isSelectionMode;
    final tertiary = ButtonType.tertiary.colors(theme);

    Future<void> handleSwipe(DismissDirection direction) async {
      onUserInteracted?.call();
      if (!viewModel.isInteractive) return;
      HapticFeedback.mediumImpact();
      if (direction == DismissDirection.endToStart) {
        unawaited(viewModel.debitOnOriginalPeriod(occurrence));
        return;
      }
      final action = await showUndebitedSwipeActionsSheet(
        context,
        carryLabel: tr.carryToCurrentPeriod(current.label(locale)),
        debitNowLabel: tr.debitOnCurrentPeriod(current.label(locale)),
      );
      if (action == UndebitedSwipeRightAction.carryToCurrentPeriod) {
        unawaited(viewModel.carryToCurrentPeriod(occurrence));
      } else if (action == UndebitedSwipeRightAction.debitOnCurrentPeriod) {
        unawaited(viewModel.debitOnCurrentPeriod(occurrence));
      }
    }

    final card = GestureDetector(
      onLongPress: viewModel.isInteractive
          ? () {
              onUserInteracted?.call();
              viewModel.enterSelection(occurrence);
            }
          : null,
      onTap: viewModel.isInteractive
          ? () {
              if (!viewModel.isSelectionMode) return;
              onUserInteracted?.call();
              viewModel.toggleSelection(occurrence);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.all(BudglySpacing.md),
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
                SizedBox(width: BudglySpacing.md),
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
                        DateFormat.yMMMMd(locale).format(occurrence.date),
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
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );

    return AnimatedSize(
      duration: UndebitedExpensesViewModel.removalDuration,
      curve: Curves.easeOut,
      child: removing
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(bottom: BudglySpacing.sm),
              child: Semantics(
                // Swipe gestures aren't discoverable for assistive tech, so
                // the two actions they trigger are also exposed as custom
                // accessibility actions on the card itself.
                customSemanticsActions: canSwipe
                    ? {
                        CustomSemanticsAction(
                          label: tr.debitOnOriginalPeriod(
                            origin.label(locale),
                          ),
                        ): () => handleSwipe(DismissDirection.endToStart),
                        CustomSemanticsAction(
                          label: tr.undebitedSwipeSheetTitle,
                        ): () => handleSwipe(DismissDirection.startToEnd),
                      }
                    : const {},
                child: Dismissible(
                  key: ValueKey(occurrence.key),
                  direction: canSwipe
                      ? DismissDirection.horizontal
                      : DismissDirection.none,
                  confirmDismiss: (direction) async {
                    await handleSwipe(direction);
                    // The list only removes a card once the underlying
                    // mutation resolves (see [viewModel.isRemoving]); the
                    // swipe gesture itself never completes the dismissal.
                    return false;
                  },
                  background: UndebitedSwipeActionBackground(
                    alignment: Alignment.centerLeft,
                    color: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    actions: [
                      UndebitedSwipeBackgroundAction(
                        icon: Icons.schedule_send_rounded,
                        label: tr.carryToCurrentPeriod(current.label(locale)),
                      ),
                      UndebitedSwipeBackgroundAction(
                        icon: Icons.check_circle_outline,
                        label: tr.debitOnCurrentPeriod(current.label(locale)),
                      ),
                    ],
                  ),
                  secondaryBackground: UndebitedSwipeActionBackground(
                    alignment: Alignment.centerRight,
                    color: tertiary.background.withAlpha(144),
                    foregroundColor: tertiary.foreground,
                    actions: [
                      UndebitedSwipeBackgroundAction(
                        icon: Icons.history_rounded,
                        label: tr.debitOnOriginalPeriod(origin.label(locale)),
                      ),
                    ],
                  ),
                  child: card,
                ),
              ),
            ),
    );
  }
}
