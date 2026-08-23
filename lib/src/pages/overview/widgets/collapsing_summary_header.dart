import 'package:budgly/src/core/extensions/currency.dart';
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

  const CollapsingSummaryHeader({
    required this.viewModel,
    required this.onSelectAccount,
    this.onEditRevenue,
    this.onCategoryTap,
    this.slideDirection = 1,
  });

  static const double _expandedExtent = 266;
  static const double _collapsedExtent = 88;

  @override
  double get maxExtent => _expandedExtent;

  @override
  double get minExtent => _collapsedExtent;

  String _formatAmount(double value) => formatCurrency(
    amount: value,
    currencyCode: viewModel.currencyCode,
    localeName: viewModel.localeName,
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

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 16,
              right: 16,
              top: 4,
              child: IgnorePointer(
                ignoring: t > 0.5,
                child: Opacity(
                  opacity: 1 - t,
                  child: PeriodSlideSwitcher(
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
            Positioned(
              left: 16,
              right: 16,
              bottom: 6,
              child: IgnorePointer(
                ignoring: t < 0.5,
                child: Opacity(
                  opacity: t,
                  child: PeriodSlideSwitcher(
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant CollapsingSummaryHeader oldDelegate) =>
      oldDelegate.viewModel != viewModel ||
      oldDelegate.onSelectAccount != onSelectAccount ||
      oldDelegate.onEditRevenue != onEditRevenue ||
      oldDelegate.onCategoryTap != onCategoryTap ||
      oldDelegate.slideDirection != slideDirection;
}
