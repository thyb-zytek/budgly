import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/pages/overview/widgets/date_selector.dart';
import 'package:budgly/src/shared/widgets/accounts/details.dart';
import 'package:budgly/src/shared/widgets/buttons/add_fab.dart';
import 'package:budgly/src/shared/widgets/categories/default.dart';
import 'package:budgly/src/shared/widgets/common/card.dart';
import 'package:budgly/src/core/routers/base.dart';
import 'package:flutter/material.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:go_router/go_router.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late final OverviewViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderExpanded = true;

  @override
  void initState() {
    super.initState();
    _viewModel = OverviewViewModel(
      onNoAccounts: () {
        if (mounted) {
          context.go(NavigationHelper.tutorialPath);
        }
      },
    );
    _viewModel.loadUserAccounts();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final isExpanded = _scrollController.offset <= 0;
    if (_isHeaderExpanded != isExpanded) {
      setState(() => _isHeaderExpanded = isExpanded);
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openModal() {}
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPinnedHeader(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.only(
                      top: 8,
                      left: 16,
                      right: 16,
                      bottom: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        DateSelector(
                          period: _viewModel.selectedPeriod,
                          onPeriodChanged: _viewModel.changePeriod,
                          maxMonthsAfter: _viewModel.limitMonthsAfter,
                          maxMonthsBefore: _viewModel.limitMonthsBefore,
                        ),
                        BudglyCard(
                          child: AccountDetails(
                            selectedAccount: _viewModel.selectedAccount,
                            onChangeAccount: _viewModel.changeAccount,
                            accounts: _viewModel.accounts,
                            incomes: _viewModel.incomeAmount,
                            outcomes: _viewModel.outcomesAmount,
                            available: _viewModel.availableAmount,
                            categories: _viewModel.categories,
                            isExpanded: _isHeaderExpanded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final category = _viewModel.categories[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: BudglyCard(
                          child: CategoryView(category: category),
                        ),
                      );
                    }, childCount: _viewModel.categories.length),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: AddFab(heroTag: "create_expense", onPressed: _openModal),
            ),
          ],
        );
      },
    );
  }
}
