import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:flutter/material.dart';

class OverviewUiState {
  final Account? account;
  final Period selectedPeriod;
  final bool showRevenueEditor;
  final bool isSaving;

  const OverviewUiState({
    this.account,
    required this.selectedPeriod,
    this.showRevenueEditor = false,
    this.isSaving = false,
  });

  OverviewUiState copyWith({
    Account? account,
    bool clearAccount = false,
    Period? selectedPeriod,
    bool? showRevenueEditor,
    bool? isSaving,
  }) {
    return OverviewUiState(
      account: clearAccount ? null : (account ?? this.account),
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      showRevenueEditor: showRevenueEditor ?? this.showRevenueEditor,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class OverviewStatItem {
  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final Color? detailColor;
  final Color color;
  final bool isEmphasized;
  final String? tooltip;
  final VoidCallback? onTap;
  final IconData? trailingIcon;

  const OverviewStatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.detailColor,
    required this.color,
    this.isEmphasized = false,
    this.tooltip,
    this.onTap,
    this.trailingIcon,
  });
}

class OverviewSummaryStats {
  final OverviewStatItem revenue;
  final OverviewStatItem expenses;
  final OverviewStatItem remaining;
  final OverviewStatItem? weekly;

  const OverviewSummaryStats({
    required this.revenue,
    required this.expenses,
    required this.remaining,
    this.weekly,
  });

  factory OverviewSummaryStats.from(
    BuildContext context,
    OverviewViewModel viewModel,
    String Function(double) formatAmount, {
    VoidCallback? onEditRevenue,
  }) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final hasRevenue = viewModel.hasRevenue;
    final isEstimated = viewModel.isRevenueEstimated;
    final isOverBudget = viewModel.remaining < 0;
    final hasPending = viewModel.pendingExpenses > 0;

    return OverviewSummaryStats(
      revenue: OverviewStatItem(
        icon: Icons.account_balance_wallet_rounded,
        label: tr.revenue,
        value: hasRevenue
            ? formatAmount(viewModel.revenue)
            : isEstimated
            ? '≈ ${formatAmount(viewModel.effectiveRevenue)}'
            : '—',
        color: theme.colorScheme.secondary,
        tooltip: isEstimated ? tr.revenueEstimatedHint : null,
        onTap: onEditRevenue,
        trailingIcon: hasRevenue ? Icons.edit_rounded : Icons.add_rounded,
      ),
      expenses: OverviewStatItem(
        icon: Icons.trending_down_rounded,

        label: hasPending
            ? '${tr.expenses} (${tr.pendingExpenses.toLowerCase()})'
            : tr.expenses,
        value: formatAmount(viewModel.totalExpenses),
        detail: hasPending ? formatAmount(viewModel.pendingExpenses) : null,
        color: theme.colorScheme.tertiary,

        detailColor: theme.colorScheme.error,
        tooltip: hasPending
            ? tr.expensesUpcomingHint(formatAmount(viewModel.pendingExpenses))
            : null,
      ),
      remaining: OverviewStatItem(
        icon: Icons.savings_rounded,
        label: tr.remaining,
        value: formatAmount(viewModel.remaining),
        color: isOverBudget
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
        isEmphasized: true,
        tooltip: hasRevenue
            ? tr.remainingBasedOnRevenueHint
            : isEstimated
            ? tr.revenueEstimatedHint
            : null,
      ),
      weekly: viewModel.weeklyBudget != null
          ? OverviewStatItem(
              icon: Icons.calendar_view_week_rounded,
              label: tr.remainingWeekend,
              value: formatAmount(viewModel.weeklyBudget!),
              color: theme.colorScheme.primary,
            )
          : null,
    );
  }
}
