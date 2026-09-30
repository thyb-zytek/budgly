import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/overview/account_selection_provider.dart';
import 'package:budgly/src/pages/overview/overview_provider.dart';
import 'package:budgly/src/pages/overview/period_expenses_provider.dart';
import 'package:budgly/src/pages/overview/revenue_provider.dart';
import 'package:budgly/src/pages/overview/widgets/overview_expenses_sliver.dart';
import 'package:budgly/src/pages/overview/widgets/collapsing_summary_header.dart';
import 'package:budgly/src/pages/overview/widgets/period_selector.dart';
import 'package:budgly/src/pages/overview/widgets/revenue_form.dart';
import 'package:budgly/src/shared/ui/widgets/gestures/horizontal_swipe_detector.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OverviewContent extends ConsumerWidget {
  const OverviewContent({
    super.key,
    required this.slideDirection,
    required this.onPeriodChanged,
    required this.onSwipe,
    required this.onCategoryTap,
    required this.onRefresh,
    required this.translations,
  });

  final ValueListenable<int> slideDirection;
  final ValueChanged<Period> onPeriodChanged;
  final ValueChanged<bool> onSwipe;
  final ValueChanged<String> onCategoryTap;
  final Future<void> Function() onRefresh;
  final AppLocalizations translations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(overviewProvider.select((s) => s.selectedPeriod));
    final accountId = ref.watch(
      accountSelectionProvider.select((s) => s.selectedAccount?.id),
    );
    final theme = Theme.of(context);

    return HorizontalSwipeDetector(
      onSwipe: (direction) => onSwipe(direction == SwipeDirection.forward),
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: PeriodSelector(
                period: period,
                minPeriod: overviewMinPeriod(),
                maxPeriod: overviewMaxPeriod(),
                revision: period.hashCode,
                theme: theme,
                onChanged: onPeriodChanged,
              ),
            ),
            if (accountId != null) ...[
              _RevenueEditorSliver(accountId: accountId, period: period),
              _SummarySliver(
                accountId: accountId,
                period: period,
                slideDirection: slideDirection,
                onSelectAccount: ref
                    .read(overviewProvider.notifier)
                    .selectAccount,
                onEditRevenue: () => ref
                    .read(revenueProvider(accountId, period).notifier)
                    .openEditor(),
                onCategoryTap: onCategoryTap,
              ),
              SliverToBoxAdapter(child: SizedBox(height: BudglySpacing.lg)),
              OverviewExpensesSliver(
                accountId: accountId,
                period: period,
                slideDirection: slideDirection,
                translations: translations,
                onCategoryTap: onCategoryTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RevenueEditorSliver extends ConsumerWidget {
  const _RevenueEditorSliver({required this.accountId, required this.period});
  final String accountId;
  final Period period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenue = ref.watch(revenueProvider(accountId, period));
    final currencyCode = ref.watch(
      profileSessionProvider.select((s) => s.currency),
    );
    final notifier = ref.read(revenueProvider(accountId, period).notifier);
    return SliverToBoxAdapter(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: revenue.showEditor
            ? Padding(
                padding: EdgeInsets.only(top: BudglySpacing.md),
                child: RevenueForm(
                  key: const ValueKey('revenue-editor'),
                  state: revenue,
                  currencyCode: currencyCode,
                  onClose: notifier.closeEditor,
                  onSave: notifier.setRevenue,
                ),
              )
            : const SizedBox.shrink(key: ValueKey('revenue-editor-hidden')),
      ),
    );
  }
}

class _SummarySliver extends ConsumerWidget {
  const _SummarySliver({
    required this.accountId,
    required this.period,
    required this.slideDirection,
    required this.onSelectAccount,
    required this.onEditRevenue,
    required this.onCategoryTap,
  });

  final String accountId;
  final Period period;
  final ValueListenable<int> slideDirection;
  final ValueChanged<Account> onSelectAccount;
  final VoidCallback onEditRevenue;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountSelectionProvider);
    final expenses = ref.watch(periodExpensesProvider(accountId, period));
    final revenue = ref.watch(revenueProvider(accountId, period));
    final profile = ref.watch(
      profileSessionProvider.select(
        (s) => (s.currency, s.locale.languageCode, s.amountDecimalPlaces),
      ),
    );
    final theme = Theme.of(context);

    // Show loading placeholder in summary while period expenses are loading
    final summaries = (!expenses.isLoaded || expenses.status.isLoading)
        ? <CategoryExpenseSummary>[]
        : expenses.categorySummaries;

    return ValueListenableBuilder<int>(
      valueListenable: slideDirection,
      builder: (context, direction, _) => SliverPersistentHeader(
        pinned: true,
        delegate: CollapsingSummaryHeader(
          accounts: accounts.accounts,
          account: accounts.selectedAccount,
          period: period,
          categorySummaries: summaries,
          revenue: revenue,
          currencyCode: profile.$1,
          localeName: profile.$2,
          amountDecimalPlaces: profile.$3,
          onSelectAccount: onSelectAccount,
          onEditRevenue: onEditRevenue,
          onCategoryTap: onCategoryTap,
          slideDirection: direction,
          revision: Object.hash(
            accounts.selectedAccount,
            period,
            summaries,
            revenue.revenue,
            revenue.inheritedRevenue,
          ),
          theme: theme,
        ),
      ),
    );
  }
}
