import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/pages/overview/widgets/donut_chart.dart';
import 'package:budgly/src/pages/overview/widgets/summary_item.dart';
import 'package:budgly/src/shared/widgets/accounts/selector.dart';
import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final OverviewViewModel viewModel;
  final VoidCallback? onEditRevenue;

  const SummaryCard({super.key, required this.viewModel, this.onEditRevenue});

  String _formatAmount(double value) {
    return formatCurrency(
      amount: value,
      currencyCode: viewModel.currencyCode,
      localeName: viewModel.localeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final summaries = viewModel.categorySummaries;
    final hasRevenue = viewModel.revenue > 0;
    final isOverBudget = viewModel.remaining < 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32).copyWith(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 32,
          children: [
            AccountSelector(
              accounts: viewModel.accounts,
              selectedAccount: viewModel.account,
              backgroundColor: theme.colorScheme.surface,
              onSelect: (acc) => viewModel.account = acc,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 32,
            children: [
              CategoryDonutChart(
                summaries: summaries,
                size: 164,
                referenceTotal: hasRevenue ? viewModel.revenue : null,
                centerChild: Column(
                  key: ValueKey(viewModel.remaining),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatAmount(viewModel.remaining),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isOverBudget
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      tr.remaining,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 14,
                  children: [
                    SummaryStat(
                      icon: Icons.trending_down_rounded,
                      label: tr.expenses,
                      value: _formatAmount(viewModel.totalExpenses),
                      color: theme.colorScheme.tertiary,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SummaryStat(
                            icon: Icons.account_balance_wallet_rounded,
                            label: tr.revenue,
                            value: hasRevenue ? _formatAmount(viewModel.revenue) : '—',
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        if (onEditRevenue != null)
                          IconButton.filledTonal(
                            onPressed: onEditRevenue,
                            tooltip: hasRevenue ? tr.validate : tr.revenue,
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(32, 32),
                              padding: EdgeInsets.zero,
                              backgroundColor: theme.colorScheme.secondaryContainer,
                              foregroundColor: theme.colorScheme.onSecondaryContainer,
                            ),
                            icon: Icon(
                              hasRevenue ? Icons.edit_rounded : Icons.add_rounded,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    if (viewModel.weeklyBudget != null)
                      SummaryStat(
                        icon: Icons.calendar_view_week_rounded,
                        label: tr.remainingWeekend,
                        value: _formatAmount(viewModel.weeklyBudget!),
                        color: theme.colorScheme.primary,
                        isEmphasized: true,
                      ),
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
}