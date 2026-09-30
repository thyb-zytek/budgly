import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/overview/revenue_provider.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter/material.dart';

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
    BuildContext context, {
    required RevenueState revenue,
    required double totalExpenses,
    required double pendingExpenses,
    required int? remainingWeekends,
    required String Function(double) formatAmount,
    VoidCallback? onEditRevenue,
  }) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final hasRevenue = revenue.hasRevenue;
    final isEstimated = revenue.isEstimated;
    final remaining = revenue.effectiveRevenue - totalExpenses;
    final weekly = remainingWeekends == null
        ? null
        : remaining / (remainingWeekends > 0 ? remainingWeekends : 1);
    final hasPending = pendingExpenses > 0;

    return OverviewSummaryStats(
      revenue: OverviewStatItem(
        icon: Icons.account_balance_wallet_rounded,
        label: tr.revenue,
        value: hasRevenue
            ? formatAmount(revenue.revenue)
            : isEstimated
            ? '≈ ${formatAmount(revenue.effectiveRevenue)}'
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
        value: formatAmount(totalExpenses),
        detail: hasPending ? formatAmount(pendingExpenses) : null,
        color: theme.colorScheme.tertiary,
        detailColor: theme.colorScheme.error,
        tooltip: hasPending
            ? tr.expensesUpcomingHint(formatAmount(pendingExpenses))
            : null,
      ),
      remaining: OverviewStatItem(
        icon: Icons.savings_rounded,
        label: tr.remaining,
        value: formatAmount(remaining),
        color: remaining < 0
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
        isEmphasized: true,
        tooltip: hasRevenue
            ? tr.remainingBasedOnRevenueHint
            : isEstimated
            ? tr.revenueEstimatedHint
            : null,
      ),
      weekly: weekly == null
          ? null
          : OverviewStatItem(
              icon: Icons.calendar_view_week_rounded,
              label: tr.remainingWeekend,
              value: formatAmount(weekly),
              color: theme.colorScheme.primary,
            ),
    );
  }
}

int? overviewRemainingWeekends(Period period) {
  if (period.isBefore(Period.current())) return null;
  if (period == Period.current()) return period.remainingWeekends();
  return period.totalWeekends();
}
