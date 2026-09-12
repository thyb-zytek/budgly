import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/undebited_expenses/view_model.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/bulk_action_bar.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/expense_occurrence_card.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/selection_banner.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/swipe_hint_wrapper.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:flutter/material.dart';

class UndebitedExpensesContent extends StatelessWidget {
  final UndebitedExpensesViewModel viewModel;

  /// Tracks the transient swipe-hint animation shown on the first card so it
  /// can be stopped as soon as the user interacts with any card. Owned by
  /// the page's state so its identity survives this widget being rebuilt.
  final GlobalKey<UndebitedSwipeHintWrapperState> swipeHintKey;

  const UndebitedExpensesContent({
    super.key,
    required this.viewModel,
    required this.swipeHintKey,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final accounts = viewModel.accounts;

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
          child: viewModel.isSelectionMode
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UndebitedSelectionBanner(viewModel: viewModel),
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
          child: viewModel.isSelectionMode &&
                  viewModel.selectedCount > 0
              ? UndebitedBulkActionBar(viewModel: viewModel)
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
      if (account.id == viewModel.selectedAccountId) {
        selected = account;
        break;
      }
    }
    return AccountSelector(
      accounts: accounts,
      selectedAccount: selected,
      onSelect: (account) => viewModel.selectAccount(account.id),
      showAllOption: true,
      isAllSelected: viewModel.selectedAccountId == null,
      allAccountsLabel: tr.allAccounts,
      onSelectAll: () => viewModel.selectAccount(null),
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
              tr.undebitedPendingCount(viewModel.totalCount),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            formatCurrency(
              amount: viewModel.totalAmount,
              currencyCode: viewModel.currencyCode,
              localeName: viewModel.localeName,
              decimalPlaces: viewModel.amountDecimalPlaces,
              forceDecimal: true,
            ),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
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
    final occurrences = viewModel.occurrences;
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
    final children = <Widget>[];
    for (final group in viewModel.grouped) {
      children.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: BudglySpacing.xs),
          child: Text(
            group.period.label(viewModel.localeName),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      for (final occurrence in group.occurrences) {
        final card = UndebitedExpenseCard(
          viewModel: viewModel,
          occurrence: occurrence,
          onUserInteracted: () => swipeHintKey.currentState?.stop(),
        );
        children.add(
          isFirstCard
              ? UndebitedSwipeHintWrapper(key: swipeHintKey, child: card)
              : card,
        );
        isFirstCard = false;
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        BudglySpacing.lg,
        BudglySpacing.xs,
        BudglySpacing.lg,
        BudglySpacing.lg,
      ),
      children: children,
    );
  }
}
