import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/pages/overview/widgets/donut_chart.dart';
import 'package:budgly/src/pages/overview/widgets/summary_stat.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:flutter/material.dart';

/// Single source of truth for the overview summary UI.
///
/// The same content is used in expanded and collapsed states. Keeping one
/// presentation widget avoids duplicated layouts and makes the two states
/// visually consistent while the sliver only controls the available height.
///
/// The expanded layout lives in a [Card] (theme chrome: elevation 0,
/// radius 16, hairline border); everything inside stays flat — the stats
/// and chart side panel sit directly on the card surface, separated by
/// whitespace and hairline dividers only.
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
      return Row(
        children: [
          if (viewModel.accounts.isNotEmpty) ...[
            AccountSelector(
              compact: true,
              accounts: viewModel.accounts,
              selectedAccount: viewModel.account,
              onSelect: onSelectAccount,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: stats.revenue.build(compact: true)),
                    const SizedBox(width: 12),
                    Expanded(child: stats.expenses.build(compact: true)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: stats.remaining.build(compact: true)),
                    const SizedBox(width: 12),
                    if (stats.weekly != null)
                      Expanded(child: stats.weekly!.build(compact: true))
                    else
                      const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (viewModel.accounts.isNotEmpty) ...[
              AccountSelector(
                accounts: viewModel.accounts,
                selectedAccount: viewModel.account,
                backgroundColor: Colors.transparent,
                onSelect: onSelectAccount,
              ),
              const SizedBox(height: 12),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: stats.revenue.build()),
                  _verticalSeparator(theme),
                  Expanded(child: stats.expenses.build()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              spacing: 16,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: CategoryDonutChart(
                    summaries: viewModel.categorySummaries,
                    size: 104,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      stats.remaining.build(),
                      if (stats.weekly != null) ...[
                        const SizedBox(height: 8),
                        Divider(
                          height: 1,
                          color: theme.colorScheme.outlineVariant.withAlpha(90),
                        ),
                        const SizedBox(height: 8),
                        stats.weekly!.build(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalSeparator(ThemeData theme) => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: theme.colorScheme.outlineVariant.withAlpha(80),
  );
}
