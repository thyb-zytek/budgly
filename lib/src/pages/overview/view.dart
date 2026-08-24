import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/navigation/navigation_helper.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/pages/overview/widgets/collapsing_summary_header.dart';
import 'package:budgly/src/pages/overview/widgets/expense_form.dart';
import 'package:budgly/src/pages/overview/widgets/period_selector.dart';
import 'package:budgly/src/pages/overview/widgets/period_slide_switcher.dart';
import 'package:budgly/src/pages/overview/widgets/revenue_form.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_expense_list.dart';
import 'package:budgly/src/shared/ui/widgets/gestures/horizontal_swipe_detector.dart';
import 'package:budgly/src/shared/ui/widgets/layout/budgly_fab.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final OverviewViewModel _viewModel = OverviewViewModel();

  int _slideDirection = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_viewModel.hasAccountsLoaded) {
      await _viewModel.loadAccounts();
    }
    if (_viewModel.accounts.isNotEmpty && _viewModel.account == null) {
      _viewModel.account = _viewModel.accounts.first;
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _openAddExpenseModal() {
    _viewModel.startNewExpense();
    showAppBottomSheet(
      context,
      builder: (context) => ExpenseForm(viewModel: _viewModel),
    );
  }

  void _onPeriodChanged(Period period) {
    final current = _viewModel.selectedPeriod;
    if (period.isAfter(current)) {
      _slideDirection = 1;
    } else if (period.isBefore(current)) {
      _slideDirection = -1;
    } else {
      return;
    }
    _viewModel.selectedPeriod = period;
  }

  void _changePeriodBySwipe(bool next) {
    final current = _viewModel.selectedPeriod;
    final target = next ? current.next : current.previous;
    if (target.isBefore(_viewModel.minPeriod) ||
        target.isAfter(_viewModel.maxPeriod)) {
      return;
    }
    _onPeriodChanged(target);
  }

  void _openCategoryDetails(String categoryId) {
    final accountId = _viewModel.account?.id;
    if (accountId == null) return;
    context.push(
      NavigationHelper.buildCategoryExpensesPath(
        accountId,
        categoryId,
        _viewModel.selectedPeriod,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return const Scaffold(body: AppLoadingIndicator());
        }

        final summaries = _viewModel.categorySummaries;

        return Scaffold(
          body: HorizontalSwipeDetector(
            onSwipe: (direction) =>
                _changePeriodBySwipe(direction == SwipeDirection.forward),
            child: RefreshIndicator(
              onRefresh: _viewModel.refreshAll,
              child: CustomScrollView(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: PeriodSelector(
                      period: _viewModel.selectedPeriod,
                      minPeriod: _viewModel.minPeriod,
                      maxPeriod: _viewModel.maxPeriod,
                      onChanged: _onPeriodChanged,
                    ),
                  ),

                  if (_viewModel.accounts.isNotEmpty)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: CollapsingSummaryHeader(
                        viewModel: _viewModel,
                        onSelectAccount: (acc) => _viewModel.account = acc,
                        onEditRevenue: _viewModel.openRevenueEditor,
                        onCategoryTap: _openCategoryDetails,
                        slideDirection: _slideDirection,
                      ),
                    ),

                  SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _viewModel.showRevenueEditor
                          ? RevenueForm(
                              key: const ValueKey('revenue-editor'),
                              viewModel: _viewModel,
                              onClose: _viewModel.closeRevenueEditor,
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('revenue-editor-hidden'),
                            ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  if (summaries.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: PeriodSlideSwitcher(
                        period: _viewModel.selectedPeriod,
                        direction: _slideDirection,
                        child: EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: tr.noExpensesForPeriod,
                          subtitle: tr.addFirstExpenseHint,
                        ),
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          tr.expensesByCategory,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                      sliver: SliverToBoxAdapter(
                        child: PeriodSlideSwitcher(
                          period: _viewModel.selectedPeriod,
                          direction: _slideDirection,
                          child: CategoryExpenseList(
                            summaries: summaries,
                            currencyCode: _viewModel.currencyCode,
                            localeName: _viewModel.localeName,
                            decimalPlaces: _viewModel.amountDecimalPlaces,
                            onTapCategory: (summary) {
                              final categoryId = summary.category.id;
                              if (categoryId == null ||
                                  _viewModel.account?.id == null) {
                                return;
                              }
                              _openCategoryDetails(categoryId);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          floatingActionButton: BudglyFab(
            heroTag: "create_expense",
            label: tr.fabNewExpense,
            onPressed: _openAddExpenseModal,
          ),
        );
      },
    );
  }
}
