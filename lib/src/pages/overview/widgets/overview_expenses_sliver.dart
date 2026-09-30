import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/overview/period_expenses_provider.dart';
import 'package:budgly/src/pages/overview/widgets/period_slide_switcher.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_expense_list.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OverviewExpensesSliver extends ConsumerWidget {
  const OverviewExpensesSliver({
    super.key,
    required this.accountId,
    required this.period,
    required this.slideDirection,
    required this.translations,
    required this.onCategoryTap,
  });

  final String accountId;
  final Period period;
  final ValueListenable<int> slideDirection;
  final AppLocalizations translations;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(periodExpensesProvider(accountId, period));
    final profile = ref.watch(
      profileSessionProvider.select(
        (s) => (s.currency, s.locale.languageCode, s.amountDecimalPlaces),
      ),
    );
    final summaries = state.categorySummaries;

    // Show localized loading while expenses for this period are still loading
    // or if we're actively loading (covers the gap between overview.hasLoaded=true
    // and periodExpenses.isLoaded propagating to the UI)
    if (!state.isLoaded || state.status.isLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: PeriodSlideSwitcher(
          period: period,
          direction: slideDirection.value,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(BudglySpacing.lg),
              child: const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }

    if (summaries.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: PeriodSlideSwitcher(
          period: period,
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              PeriodSlideSwitcher(
                period: period,
                direction: direction,
                child: CategoryExpenseList(
                  summaries: summaries,
                  currencyCode: profile.$1,
                  localeName: profile.$2,
                  decimalPlaces: profile.$3,
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
