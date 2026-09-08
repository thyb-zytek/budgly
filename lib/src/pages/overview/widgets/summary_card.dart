import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/overview/ui_state.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/pages/overview/widgets/donut_chart.dart';
import 'package:budgly/src/pages/overview/widgets/overview_stat.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:flutter/material.dart';

class OverviewSummaryCard extends StatelessWidget {
  final OverviewViewModel viewModel;
  final ValueChanged<Account> onSelectAccount;
  final VoidCallback? onEditRevenue;
  final String Function(double) formatAmount;
  final bool compact;
  final ValueChanged<String>? onCategoryTap;

  const OverviewSummaryCard({
    super.key,
    required this.viewModel,
    required this.onSelectAccount,
    required this.onEditRevenue,
    required this.formatAmount,
    this.compact = false,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = OverviewSummaryStats.from(
      context,
      viewModel,
      formatAmount,
      onEditRevenue: onEditRevenue,
    );

    if (compact) {
      return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BudglySpacing.md,
            vertical: BudglySpacing.sm,
          ),
          child: Row(
            spacing: BudglySpacing.lg,
            children: [
              if (viewModel.accounts.isNotEmpty)
                AccountSelector(
                  compact: true,
                  accounts: viewModel.accounts,
                  selectedAccount: viewModel.account,
                  onSelect: onSelectAccount,
                ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: BudglySpacing.sm,
                  children: [
                    Row(
                      spacing: BudglySpacing.lg,
                      children: [
                        Expanded(
                          child: OverviewStat(
                            item: stats.revenue,
                            compact: true,
                          ),
                        ),
                        Expanded(
                          child: OverviewStat(
                            item: stats.expenses,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      spacing: BudglySpacing.lg,
                      children: [
                        Expanded(
                          child: OverviewStat(
                            item: stats.remaining,
                            compact: true,
                          ),
                        ),
                        if (stats.weekly != null)
                          Expanded(
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

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(BudglySpacing.md),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BudglySpacing.lg,
          children: [
            if (viewModel.accounts.isNotEmpty)
              AccountSelector(
                accounts: viewModel.accounts,
                selectedAccount: viewModel.account,
                backgroundColor: Colors.transparent,
                onSelect: onSelectAccount,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BudglySpacing.md),
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
              spacing: BudglySpacing.lg,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BudglySpacing.md),
                  child: RepaintBoundary(
                    child: CategoryDonutChart(
                      summaries: viewModel.categorySummaries,
                      size: 96,
                      strokeWidthFactor: 0.18,
                      referenceTotal: viewModel.effectiveRevenue > 0
                          ? viewModel.effectiveRevenue
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
                          color: theme.colorScheme.outlineVariant.withAlpha(90),
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
