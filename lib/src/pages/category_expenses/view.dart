import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/pages/category_expenses/view_model.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/category_expenses/widgets/expense_edit_sheet.dart';
import 'package:budgly/src/pages/category_expenses/widgets/expense_occurrence_tile.dart';
import 'package:budgly/src/pages/category_expenses/widgets/swipe_hint_wrapper.dart';
import 'package:budgly/src/shared/widgets/categories/category_expenses.dart';
import 'package:budgly/src/shared/widgets/layout/empty_state.dart';
import 'package:budgly/src/shared/widgets/layout/loading_indicator.dart';
import 'package:flutter/material.dart';

/// Lists every expense occurrence of a category (recurring ones expanded
/// automatically): undebited first, then most recent first.
///
/// Rows can be tapped to open the edit sheet or swiped (left to toggle the
/// debited state, right to edit). A periodic swipe hint animates over the
/// first row until the user interacts with it.
class CategoryExpensesPage extends StatefulWidget {
  final String accountId;
  final String categoryId;
  final Period period;

  const CategoryExpensesPage({
    super.key,
    required this.accountId,
    required this.categoryId,
    required this.period,
  });

  @override
  State<CategoryExpensesPage> createState() => _CategoryExpensesPageState();
}

class _CategoryExpensesPageState extends State<CategoryExpensesPage> {
  final GlobalKey<SwipeHintWrapperState> _swipeHintKey =
      GlobalKey<SwipeHintWrapperState>();

  late final CategoryExpensesViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = CategoryExpensesViewModel(
      accountId: widget.accountId,
      categoryId: widget.categoryId,
      period: widget.period,
    );
    _viewModel.ensureDataLoaded();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _openEditSheet(ExpenseOccurrence occurrence) {
    _viewModel.startEditing(occurrence);
    showAppBottomSheet(
      context,
      builder: (context) => ExpenseEditSheet(viewModel: _viewModel),
    );
  }

  Future<void> _toggleDebited(ExpenseOccurrence occurrence) async {
    final tr = AppLocalizations.of(context)!;
    final wasDebited = occurrence.isDebited;

    final success = await _viewModel.toggleDebited(occurrence);
    if (!mounted || !success) return;

    showAppSnackBar(
      context,
      message: wasDebited
          ? tr.expenseMarkedAsPending
          : tr.expenseMarkedAsDebited,
      type: SnackBarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading || _viewModel.category == null) {
          return const Scaffold(body: AppLoadingIndicator());
        }

        final occurrences = _viewModel.occurrences;
        final summary = _viewModel.summary!;

        return Scaffold(
          appBar: AppBar(
            title: Text(summary.category.name ?? ''),
          ),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: CategoryExpenses(
                    summary: summary,
                    currencyCode: _viewModel.currencyCode,
                    localeName: _viewModel.localeName,
                  ),
                ),
              ),
              if (occurrences.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: tr.noExpensesForCategory,
                    subtitle: tr.noExpensesForCategoryHint,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  sliver: SliverList.separated(
                    itemCount: occurrences.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final occurrence = occurrences[index];
                      final tile = ExpenseOccurrenceTile(
                        occurrence: occurrence,
                        currencyCode: _viewModel.currencyCode,
                        localeName: _viewModel.localeName,
                        onTap: () => _openEditSheet(occurrence),
                        onEdit: () => _openEditSheet(occurrence),
                        onToggleDebited: () => _toggleDebited(occurrence),
                        onUserInteracted: () =>
                            _swipeHintKey.currentState?.stop(),
                      );
                      return index == 0
                          ? SwipeHintWrapper(key: _swipeHintKey, child: tile)
                          : tile;
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
