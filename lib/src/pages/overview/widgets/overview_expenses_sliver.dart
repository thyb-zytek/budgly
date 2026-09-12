import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/pages/overview/widgets/period_slide_switcher.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_expense_list.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class OverviewExpensesSliver extends StatelessWidget {
  final OverviewViewModel viewModel;
  final ValueListenable<int> slideDirection;
  final AppLocalizations translations;
  final ValueChanged<String> onCategoryTap;

  const OverviewExpensesSliver({
    super.key,
    required this.viewModel,
    required this.slideDirection,
    required this.translations,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final summaries = viewModel.categorySummaries;
    if (summaries.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: PeriodSlideSwitcher(
          period: viewModel.selectedPeriod,
          direction: slideDirection.value,
          child: EmptyState(
            icon: Icons.receipt_long_rounded,
            title: translations.noExpensesForPeriod,
            subtitle: translations.addFirstExpenseHint,
          ),
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: slideDirection,
      builder: (context, direction, child) => SliverPadding(
        padding: EdgeInsets.fromLTRB(BudglySpacing.lg, 0, BudglySpacing.lg, 88),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BudglySpacing.sm,
            children: [
              Text(
                translations.expensesByCategory,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              PeriodSlideSwitcher(
                period: viewModel.selectedPeriod,
                direction: direction,
                child: CategoryExpenseList(
                  summaries: summaries,
                  currencyCode: viewModel.currencyCode,
                  localeName: viewModel.localeName,
                  decimalPlaces: viewModel.amountDecimalPlaces,
                  onTapCategory: (summary) {
                    final categoryId = summary.category.id;
                    if (categoryId != null) onCategoryTap(categoryId);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
