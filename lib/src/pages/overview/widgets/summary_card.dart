import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/pages/overview/revenue_provider.dart';
import 'package:budgly/src/pages/overview/ui_state.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/pages/overview/widgets/donut_chart.dart';
import 'package:budgly/src/pages/overview/widgets/overview_stat.dart';
import 'package:flutter/material.dart';

class OverviewSummaryCard extends StatelessWidget {
  const OverviewSummaryCard({
    super.key,
    required this.accounts,
    required this.account,
    required this.period,
    required this.categorySummaries,
    required this.revenue,
    required this.formatAmount,
    required this.onSelectAccount,
    this.onEditRevenue,
    this.compact = false,
    this.onCategoryTap,
  });

  final List<Account> accounts;
  final Account? account;
  final Period period;
  final List<CategoryExpenseSummary> categorySummaries;
  final RevenueState revenue;
  final String Function(double) formatAmount;
  final ValueChanged<Account> onSelectAccount;
  final VoidCallback? onEditRevenue;
  final bool compact;
  final ValueChanged<String>? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return _buildSummaryView(context);
  }

  Widget _buildSummaryView(BuildContext context) {
    final theme = Theme.of(context);
    final totalExpenses = categorySummaries.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final pendingExpenses = categorySummaries.fold<double>(
      0,
      (sum, item) => sum + item.undebited,
    );
    final stats = OverviewSummaryStats.from(
      context,
      revenue: revenue,
      totalExpenses: totalExpenses,
      pendingExpenses: pendingExpenses,
      remainingWeekends: overviewRemainingWeekends(period),
      formatAmount: formatAmount,
      onEditRevenue: onEditRevenue,
    );

    return compact
        ? _buildCompactSummary(stats)
        : _buildExpandedSummary(context, theme, stats);
  }

  Widget _buildCompactSummary(OverviewSummaryStats stats) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: BudglySpacing.md,
          vertical: BudglySpacing.sm,
        ),
        child: Row(
          spacing: BudglySpacing.md,
          children: [
            if (accounts.isNotEmpty)
              AccountSelector(
                compact: true,
                accounts: accounts,
                selectedAccount: account,
                onSelect: onSelectAccount,
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: BudglySpacing.sm,
                children: [
                  Row(
                    spacing: BudglySpacing.xxs,
                    children: [
                      Expanded(
                        flex: 3,
                        child: OverviewStat(item: stats.revenue, compact: true),
                      ),
                      Expanded(
                        flex: 4,
                        child: OverviewStat(
                          item: stats.expenses,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    spacing: BudglySpacing.xxs,
                    children: [
                      Expanded(
                        flex: 3,
                        child: OverviewStat(
                          item: stats.remaining,
                          compact: true,
                        ),
                      ),
                      if (stats.weekly != null)
                        Expanded(
                          flex: 4,
                          child: OverviewStat(
                            item: stats.weekly!,
                            compact: true,
                          ),
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSummary(
    BuildContext context,
    ThemeData theme,
    OverviewSummaryStats stats,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(BudglySpacing.md),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BudglySpacing.lg,
            children: [
              if (accounts.isNotEmpty)
                AccountSelector(
                  accounts: accounts,
                  selectedAccount: account,
                  backgroundColor: Colors.transparent,
                  onSelect: onSelectAccount,
                ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: BudglySpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: OverviewStat(item: stats.revenue)),
                    const VerticalDivider(width: 21, thickness: 1),
                    Expanded(child: OverviewStat(item: stats.expenses)),
                  ],
                ),
              ),
              Row(
                spacing: BudglySpacing.xxs,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: BudglySpacing.md),
                    child: RepaintBoundary(
                      child: CategoryDonutChart(
                        summaries: categorySummaries,
                        size: 96,
                        strokeWidthFactor: 0.18,
                        referenceTotal: revenue.effectiveRevenue > 0
                            ? revenue.effectiveRevenue
                            : null,
                        onCategoryTap: (summary) {
                          final id = summary.category.id;
                          if (id != null) onCategoryTap?.call(id);
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: BudglySpacing.sm,
                      children: [
                        OverviewStat(item: stats.remaining),
                        if (stats.weekly != null) ...[
                          Divider(
                            height: 1,
                            color: theme.colorScheme.outlineVariant.withAlpha(
                              90,
                            ),
                          ),
                          OverviewStat(item: stats.weekly!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
