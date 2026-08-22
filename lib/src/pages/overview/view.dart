import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/navigation/navigation_helper.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/component_styles.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/pages/overview/widgets/expense_form.dart';
import 'package:budgly/src/pages/overview/widgets/period_selector.dart';
import 'package:budgly/src/pages/overview/widgets/revenue_form.dart';
import 'package:budgly/src/pages/overview/widgets/summary.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_expenses.dart';
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
    _viewModel.selectedPeriod = period;
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
          body: RefreshIndicator(
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

                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _viewModel.showRevenueEditor
                        ? RevenueForm(
                            key: const ValueKey('revenue-editor'),
                            viewModel: _viewModel,
                            onClose: _viewModel.closeRevenueEditor,
                          )
                        : const SizedBox.shrink(key: ValueKey('revenue-editor-hidden')),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverToBoxAdapter(
                    child: SummaryCard(
                      viewModel: _viewModel,
                      onEditRevenue: _viewModel.openRevenueEditor,
                    ),
                  ),
                ),

                if (summaries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: tr.noExpensesForPeriod,
                      subtitle: tr.addFirstExpenseHint,
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        tr.expensesByCategory,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    sliver: SliverList.separated(
                      itemCount: summaries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final summary = summaries[index];
                        final categoryId = summary.category.id;

                        return CategoryExpenses(
                          summary: summary,
                          currencyCode: _viewModel.currencyCode,
                          localeName: _viewModel.localeName,
                          onTap: categoryId == null || _viewModel.account?.id == null
                              ? null
                              : () {
                                  context.push(
                                    NavigationHelper.buildCategoryExpensesPath(
                                      _viewModel.account!.id!,
                                      categoryId,
                                      _viewModel.selectedPeriod,
                                    ),
                                  );
                                },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: "create_expense",
            onPressed: _openAddExpenseModal,
            child: Icon(
              Icons.add_rounded,
              size: BudglyComponentStyles.fabIconSize,
            ),
          ),
        );
      },
    );
  }
}
