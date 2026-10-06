import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/pages/undebited_expenses/undebited_expenses_provider.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/bulk_action_bar.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/expense_occurrence_card.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/selection_banner.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/swipe_hint_wrapper.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:flutter/material.dart';

class UndebitedExpensesContent extends StatelessWidget {
  final UndebitedExpensesState state;
  final UndebitedExpenses notifier;

  /// Tracks the transient swipe-hint animation shown on the first card so it
  /// can be stopped as soon as the user interacts with any card. Owned by
  /// the page's state so its identity survives this widget being rebuilt.
  final GlobalKey<UndebitedSwipeHintWrapperState> swipeHintKey;

  const UndebitedExpensesContent({
    super.key,
    required this.state,
    required this.notifier,
    required this.swipeHintKey,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final accounts = state.accounts;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            BudglySpacing.lg,
            BudglySpacing.sm,
            BudglySpacing.lg,
            BudglySpacing.xs,
          ),
          child: _buildAccountFilter(context, accounts, tr),
        ),
        _buildSummaryHeader(context, tr, theme),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: state.selectionMode
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UndebitedSelectionBanner(state: state, notifier: notifier),
                    _buildSelectionModeHint(context, tr, theme),
                  ],
                )
              : _buildGestureHint(context, tr, theme),
        ),
        Expanded(child: _buildList(context, tr, theme)),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.hardEdge,
          child: state.selectionMode && state.selectedCount > 0
              ? UndebitedBulkActionBar(state: state, notifier: notifier)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildAccountFilter(
    BuildContext context,
    List<Account> accounts,
    AppLocalizations tr,
  ) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    Account? selected;
    for (final account in accounts) {
      if (account.id == state.selectedAccountId) {
        selected = account;
        break;
      }
    }
    return AccountSelector(
      accounts: accounts,
      selectedAccount: selected,
      onSelect: (account) => notifier.selectAccount(account.id),
      showAllOption: true,
      isAllSelected: state.selectedAccountId == null,
      allAccountsLabel: tr.allAccounts,
      onSelectAll: () => notifier.selectAccount(null),
    );
  }

  Widget _buildSummaryHeader(
    BuildContext context,
    AppLocalizations tr,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        BudglySpacing.lg,
        BudglySpacing.sm,
        BudglySpacing.lg,
        BudglySpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr.undebitedPendingCount(state.totalCount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            formatCurrency(
              amount: state.totalAmount,
              currencyCode: state.currencyCode,
              localeName: state.localeName,
              decimalPlaces: state.amountDecimalPlaces,
              forceDecimal: true,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Shown above the list outside of selection mode: explains both ways to
  /// act on a card now that the per-item buttons are gone (swipe for quick
  /// actions, long-press to start a multi-select).
  Widget _buildGestureHint(
    BuildContext context,
    AppLocalizations tr,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        BudglySpacing.lg,
        BudglySpacing.xs,
        BudglySpacing.lg,
        BudglySpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: BudglySpacing.sm),
          Expanded(
            child: Text(
              tr.undebitedLongPressHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown while in selection mode, right below the selection strip: swipe
  /// is disabled there (it would be ambiguous with toggling a card), so this
  /// clarifies the tap-to-toggle behavior instead.
  Widget _buildSelectionModeHint(
    BuildContext context,
    AppLocalizations tr,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        BudglySpacing.lg,
        BudglySpacing.xs,
        BudglySpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: BudglySpacing.sm),
          Expanded(
            child: Text(
              tr.undebitedSelectionModeHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations tr,
    ThemeData theme,
  ) {
    final occurrences = state.displayed;
    if (occurrences.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: BudglySpacing.xxl),
        child: EmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: tr.undebitedNoExpenses,
        ),
      );
    }
    var isFirstCard = true;
    final items = <({Period? period, ExpenseOccurrence? occurrence})>[];
    for (final group in state.grouped) {
      items.add((period: group.period, occurrence: null));
      for (final occurrence in group.occurrences) {
        items.add((period: null, occurrence: occurrence));
      }
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        BudglySpacing.lg,
        BudglySpacing.xs,
        BudglySpacing.lg,
        BudglySpacing.lg,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final period = item.period;
        if (period != null) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: BudglySpacing.xs),
            child: Text(
              period.label(state.localeName),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final occurrence = item.occurrence!;
        final card = UndebitedExpenseCard(
          state: state,
          notifier: notifier,
          occurrence: occurrence,
          onUserInteracted: () => swipeHintKey.currentState?.stop(),
        );
        if (!isFirstCard) return card;
        isFirstCard = false;
        return UndebitedSwipeHintWrapper(key: swipeHintKey, child: card);
      },
    );
  }
}
