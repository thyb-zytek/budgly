import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/budget/period.dart';
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
            ViewModelSelector<OverviewViewModel, (Period, int)>(
              model: viewModel,
              selector: (model) => (model.selectedPeriod, model.dataRevision),
              builder: (context, value) => SliverPersistentHeader(
                pinned: true,
                delegate: PeriodSelector(
                  period: value.$1,
                  minPeriod: viewModel.minPeriod,
                  maxPeriod: viewModel.maxPeriod,
                  revision: value.$2,
                  onChanged: onPeriodChanged,
                ),
              ),
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
            ViewModelSelector<OverviewViewModel, String?>(
              model: viewModel,
              selector: (model) =>
                  '${model.account?.id}|${model.selectedPeriod}|${model.dataRevision}',
              builder: (context, _) {
                if (viewModel.accounts.isEmpty) {
                  return const SliverToBoxAdapter();
                }
                return ValueListenableBuilder<int>(
                  valueListenable: slideDirection,
                  builder: (context, direction, child) =>
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: CollapsingSummaryHeader(
                          viewModel: viewModel,
                          onSelectAccount: (account) =>
                              viewModel.account = account,
                          onEditRevenue: viewModel.openRevenueEditor,
                          onCategoryTap: onCategoryTap,
                          slideDirection: direction,
                          revision: viewModel.dataRevision,
                        ),
                      ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: BudglySpacing.lg)),
            ViewModelSelector<OverviewViewModel, String>(
              model: viewModel,
              selector: (model) =>
                  '${model.selectedPeriod}|${model.account?.id}|${model.dataRevision}',
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
