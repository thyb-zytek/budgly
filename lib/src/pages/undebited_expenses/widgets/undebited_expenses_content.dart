import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/undebited_expenses/view_model.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/bulk_action_bar.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/expense_occurrence_card.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/selection_banner.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:flutter/material.dart';

class UndebitedExpensesContent extends StatelessWidget {
  final UndebitedExpensesViewModel viewModel;

  const UndebitedExpensesContent({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final accounts = viewModel.accounts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
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
              ? UndebitedSelectionBanner(viewModel: viewModel)
              : _buildLongPressHint(context, tr, theme),
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
      padding: const EdgeInsets.fromLTRB(
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

  Widget _buildLongPressHint(
    BuildContext context,
    AppLocalizations tr,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BudglySpacing.lg,
        BudglySpacing.xs,
        BudglySpacing.lg,
        BudglySpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: BudglySpacing.sm),
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

  Widget _buildList(
    BuildContext context,
    AppLocalizations tr,
    ThemeData theme,
  ) {
    final occurrences = viewModel.occurrences;
    if (occurrences.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: BudglySpacing.xxl),
        child: EmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: tr.undebitedNoExpenses,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BudglySpacing.lg,
        BudglySpacing.xs,
        BudglySpacing.lg,
        BudglySpacing.lg,
      ),
      children: [
        for (final group in viewModel.grouped) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BudglySpacing.xs),
            child: Text(
              group.period.label(viewModel.localeName),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final occurrence in group.occurrences)
            UndebitedExpenseCard(
              viewModel: viewModel,
              occurrence: occurrence,
            ),
        ],
      ],
    );
  }
}