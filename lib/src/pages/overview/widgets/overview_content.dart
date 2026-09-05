import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/pages/overview/widgets/overview_expenses_sliver.dart';
import 'package:budgly/src/pages/overview/widgets/collapsing_summary_header.dart';
import 'package:budgly/src/pages/overview/widgets/period_selector.dart';
import 'package:budgly/src/pages/overview/widgets/revenue_form.dart';
import 'package:budgly/src/core/view_models/view_model_selector.dart';
import 'package:budgly/src/shared/ui/widgets/gestures/horizontal_swipe_detector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class OverviewContent extends StatelessWidget {
  final OverviewViewModel viewModel;
  final ValueListenable<int> slideDirection;
  final ValueChanged<Period> onPeriodChanged;
  final ValueChanged<bool> onSwipe;
  final ValueChanged<String> onCategoryTap;
  final Future<void> Function() onRefresh;
  final AppLocalizations translations;

  const OverviewContent({
    super.key,
    required this.viewModel,
    required this.slideDirection,
    required this.onPeriodChanged,
    required this.onSwipe,
    required this.onCategoryTap,
    required this.onRefresh,
    required this.translations,
  });

  @override
  Widget build(BuildContext context) {
    return HorizontalSwipeDetector(
      onSwipe: (direction) => onSwipe(direction == SwipeDirection.forward),
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          slivers: [
            ViewModelSelector<OverviewViewModel, Period>(
              model: viewModel,
              selector: (model) => model.selectedPeriod,
              builder: (context, value) {
                // Re-read the theme on every builder run so a theme change
                // both rebuilds the selector and lets shouldRebuild notice it.
                final theme = Theme.of(context);
                return SliverPersistentHeader(
                  pinned: true,
                  delegate: PeriodSelector(
                    period: value,
                    minPeriod: viewModel.minPeriod,
                    maxPeriod: viewModel.maxPeriod,
                    revision: value.hashCode,
                    theme: theme,
                    onChanged: onPeriodChanged,
                  ),
                );
              },
            ),
            ViewModelSelector<OverviewViewModel, bool>(
              model: viewModel,
              selector: (model) => model.showRevenueEditor,
              builder: (context, showEditor) => SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: showEditor
                      ? Padding(
                          padding: const EdgeInsets.only(top: BudglySpacing.md),
                          child: RevenueForm(
                            key: const ValueKey('revenue-editor'),
                            viewModel: viewModel,
                            onClose: viewModel.closeRevenueEditor,
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('revenue-editor-hidden'),
                        ),
                ),
              ),
            ),
            ViewModelSelector<OverviewViewModel, (Account?, String, Period, List<CategoryExpenseSummary>, double, double, double, double, double?, String, String, int)>(
              model: viewModel,
              selector: (model) => (
                model.account,
                model.accounts
                    .map((account) => '${account.id}|${account.name}|${account.color}|${account.pictureUrl}')
                    .join(';;'),
                model.selectedPeriod,
                model.categorySummaries,
                model.revenue,
                model.effectiveRevenue,
                model.totalExpenses,
                model.remaining,
                model.weeklyBudget,
                model.currencyCode,
                model.localeName,
                model.amountDecimalPlaces,
              ),
              builder: (context, snapshot) {
                if (viewModel.accounts.isEmpty) {
                  return const SliverToBoxAdapter();
                }
                return ValueListenableBuilder<int>(
                  valueListenable: slideDirection,
                  builder: (context, direction, child) {
                    final theme = Theme.of(context);
                    return SliverPersistentHeader(
                      pinned: true,
                      delegate: CollapsingSummaryHeader(
                        viewModel: viewModel,
                        onSelectAccount: (account) =>
                            viewModel.account = account,
                        onEditRevenue: viewModel.openRevenueEditor,
                        onCategoryTap: onCategoryTap,
                        slideDirection: direction,
                        revision: snapshot.hashCode,
                        theme: theme,
                      ),
                    );
                  },
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: BudglySpacing.lg)),
            ViewModelSelector<OverviewViewModel, (Period, String?, List<CategoryExpenseSummary>, String, String, int)>(
              model: viewModel,
              selector: (model) => (
                model.selectedPeriod,
                model.account?.id,
                model.categorySummaries,
                model.currencyCode,
                model.localeName,
                model.amountDecimalPlaces,
              ),
              builder: (context, _) => OverviewExpensesSliver(
                viewModel: viewModel,
                slideDirection: slideDirection,
                translations: translations,
                onCategoryTap: onCategoryTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
