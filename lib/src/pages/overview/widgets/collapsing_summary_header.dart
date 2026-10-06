import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/pages/overview/revenue_provider.dart';
import 'package:budgly/src/pages/overview/widgets/period_slide_switcher.dart';
import 'package:budgly/src/pages/overview/widgets/summary_card.dart';
import 'package:flutter/material.dart';

class CollapsingSummaryHeader extends SliverPersistentHeaderDelegate {
  const CollapsingSummaryHeader({
    required this.accounts,
    required this.account,
    required this.period,
    required this.categorySummaries,
    required this.revenue,
    required this.currencyCode,
    required this.localeName,
    required this.amountDecimalPlaces,
    required this.onSelectAccount,
    required this.revision,
    required this.theme,
    this.onEditRevenue,
    this.onCategoryTap,
    this.slideDirection = 1,
  });

  final List<Account> accounts;
  final Account? account;
  final Period period;
  final List<CategoryExpenseSummary> categorySummaries;
  final RevenueState revenue;
  final String currencyCode;
  final String localeName;
  final int amountDecimalPlaces;
  final ValueChanged<Account> onSelectAccount;
  final VoidCallback? onEditRevenue;
  final ValueChanged<String>? onCategoryTap;
  final int slideDirection;
  final int revision;
  final ThemeData theme;

  static const double _expandedExtent = 280;
  static const double _collapsedExtent = 136;

  @override
  double get maxExtent => _expandedExtent;
  @override
  double get minExtent => _collapsedExtent;

  String _formatAmount(double value) => formatCurrency(
    amount: value,
    currencyCode: currencyCode,
    localeName: localeName,
    decimalPlaces: amountDecimalPlaces,
  );

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final height = (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    final compact = t >= 0.5;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.all(BudglySpacing.sm),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: PeriodSlideSwitcher(
              key: ValueKey(compact),
              period: period,
              direction: slideDirection,
              child: OverviewSummaryCard(
                compact: compact,
                accounts: accounts,
                account: account,
                period: period,
                categorySummaries: categorySummaries,
                revenue: revenue,
                formatAmount: _formatAmount,
                onSelectAccount: onSelectAccount,
                onEditRevenue: onEditRevenue,
                onCategoryTap: onCategoryTap,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant CollapsingSummaryHeader oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.revision != revision ||
      oldDelegate.slideDirection != slideDirection ||
      // Formatting inputs: the same raw amounts render differently once the
      // currency, locale or precision changes, so a value-only `revision`
      // comparison would keep the previous formatted strings on screen.
      oldDelegate.currencyCode != currencyCode ||
      oldDelegate.localeName != localeName ||
      oldDelegate.amountDecimalPlaces != amountDecimalPlaces;
}
