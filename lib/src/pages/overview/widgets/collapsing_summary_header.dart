import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/pages/overview/widgets/period_slide_switcher.dart';
import 'package:budgly/src/pages/overview/widgets/summary_card.dart';
import 'package:flutter/material.dart';

class CollapsingSummaryHeader extends SliverPersistentHeaderDelegate {
  final OverviewViewModel viewModel;
  final ValueChanged<Account> onSelectAccount;
  final VoidCallback? onEditRevenue;
  final ValueChanged<String>? onCategoryTap;

  final int slideDirection;
  final int revision;
  final ThemeData theme;

  const CollapsingSummaryHeader({
    required this.viewModel,
    required this.onSelectAccount,
    this.onEditRevenue,
    this.onCategoryTap,
    this.slideDirection = 1,
    required this.revision,
    required this.theme,
  });

  static const double _expandedExtent = 280;
  static const double _collapsedExtent = 136;

  @override
  double get maxExtent => _expandedExtent;

  @override
  double get minExtent => _collapsedExtent;

  String _formatAmount(double value) => formatCurrency(
    amount: value,
    currencyCode: viewModel.currencyCode,
    localeName: viewModel.localeName,
    decimalPlaces: viewModel.amountDecimalPlaces,
  );

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final range = maxExtent - minExtent;
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    final height = (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);

    final isCompact = t >= 0.5;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.all(BudglySpacing.sm),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: isCompact
                ? PeriodSlideSwitcher(
                    key: const ValueKey('compact'),
                    period: viewModel.selectedPeriod,
                    direction: slideDirection,
                    child: OverviewSummaryCard(
                      viewModel: viewModel,
                      onSelectAccount: onSelectAccount,
                      onEditRevenue: onEditRevenue,
                      formatAmount: _formatAmount,
                      compact: true,
                      onCategoryTap: onCategoryTap,
                    ),
                  )
                : PeriodSlideSwitcher(
                    key: const ValueKey('expanded'),
                    period: viewModel.selectedPeriod,
                    direction: slideDirection,
                    child: OverviewSummaryCard(
                      viewModel: viewModel,
                      onSelectAccount: onSelectAccount,
                      onEditRevenue: onEditRevenue,
                      formatAmount: _formatAmount,
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
      oldDelegate.viewModel != viewModel ||
      oldDelegate.onSelectAccount != onSelectAccount ||
      oldDelegate.onEditRevenue != onEditRevenue ||
      oldDelegate.onCategoryTap != onCategoryTap ||
      oldDelegate.slideDirection != slideDirection ||
      oldDelegate.revision != revision;
}
