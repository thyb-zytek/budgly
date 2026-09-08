import 'dart:async';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/navigation/navigation_helper.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/view_models/view_model_selector.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_editor_sheet.dart';
import 'package:budgly/src/shared/ui/widgets/layout/framed_container.dart';
import 'package:budgly/src/shared/ui/widgets/layout/section_label.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/undebited_expenses_banner.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/domain/widgets/categories/selector.dart';
import 'package:budgly/src/pages/overview/widgets/overview_content.dart';
import 'package:budgly/src/shared/ui/widgets/layout/budgly_fab.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/view_model_feedback.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OverviewPage extends StatefulWidget {
  final OverviewViewModel? injectedViewModel;

  const OverviewPage({super.key, this.injectedViewModel});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late final OverviewViewModel _viewModel;
  late final bool _ownsViewModel;
  final ValueNotifier<int> _slideDirection = ValueNotifier(1);
  final ValueNotifier<bool> _showFabLabel = ValueNotifier(true);
  Timer? _fabLabelTimer;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.injectedViewModel == null;
    _viewModel = widget.injectedViewModel ?? OverviewViewModel();
    _loadData();
    _fabLabelTimer = Timer(const Duration(seconds: 8), () {
      _showFabLabel.value = false;
    });
  }

  Future<void> _loadData() => _viewModel.loadInitialData();

  @override
  void dispose() {
    _fabLabelTimer?.cancel();
    _showFabLabel.dispose();
    _slideDirection.dispose();
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  void _openAddExpenseModal() {
    final tr = AppLocalizations.of(context)!;
    _showFabLabel.value = false;
    _fabLabelTimer?.cancel();
    _viewModel.startNewExpense();
    showAppBottomSheet(
      context,
      builder: (context) => ExpenseEditorSheet(
        listenable: _viewModel,
        editingData: _viewModel.expenseForm.data,
        title: tr.newExpense,
        currencyCode: _viewModel.currencyCode,
        localeName: _viewModel.localeName,
        validate: (tr) => _viewModel.expenseForm.validate(
          tr,
          requireAccountAndCategory: true,
        ),
        onSubmit: _viewModel.createExpense,
        onToggleAdvanced: _viewModel.expenseForm.toggleAdvancedOptions,
        onDateChanged: _viewModel.expenseForm.setDebitDate,
        onRecurrenceChanged: _viewModel.expenseForm.setRecurrence,
        onEndDateChanged: _viewModel.expenseForm.setEndDate,
        onEndDateCleared: _viewModel.expenseForm.clearEndDate,
        isSaving: () => _viewModel.isSaving,
        isSubmitEnabled: () => _viewModel.categoriesForSelectedAccount().isNotEmpty &&
            _viewModel.expenseForm.data.account != null &&
            _viewModel.expenseForm.data.category != null,
        preFieldsBuilder: (context) {
          final theme = Theme.of(context);
          final data = _viewModel.expenseForm.data;
          final categories = _viewModel.categoriesForSelectedAccount();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  SectionLabel(tr.account),
                  FramedContainer(
                    child: AccountSelector(
                      accounts: _viewModel.accounts,
                      selectedAccount: data.account,
                      backgroundColor: theme.colorScheme.surface,
                      onSelect: _viewModel.selectFormAccount,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  SectionLabel(tr.category),
                  categories.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            spacing: 8,
                            children: [
                              Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
                              Expanded(
                                child: Text(
                                  tr.noCategoryForAccount,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : FramedContainer(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: CategorySelector(
                            categories: categories,
                            selectedCategory: data.category,
                            onSelect: _viewModel.selectFormCategory,
                          ),
                        ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _onPeriodChanged(Period period) {
    final current = _viewModel.selectedPeriod;
    if (period.isAfter(current)) {
      _slideDirection.value = 1;
    } else if (period.isBefore(current)) {
      _slideDirection.value = -1;
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

    return Scaffold(
      body: Column(
        children: [
          ViewModelSelector<OverviewViewModel, Object?>(
            model: _viewModel,
            selector: (model) => (
              model.amountDecimalPlaces,
              model.currencyCode,
              model.localeName,
            ),
            builder: (context, _) => UndebitedExpensesBanner(
              service: _viewModel.undebitedExpensesService,
              currencyCode: _viewModel.currencyCode,
              localeName: _viewModel.localeName,
              amountDecimalPlaces: _viewModel.amountDecimalPlaces,
            ),
          ),
          Expanded(
            child: ViewModelFeedback(
              viewModel: _viewModel,
              child: ViewModelSelector<OverviewViewModel, bool>(
                model: _viewModel,
                selector: (model) => model.isLoading,
                builder: (context, isLoading) => isLoading
                    ? const AppLoadingIndicator()
                    : OverviewContent(
                        viewModel: _viewModel,
                        slideDirection: _slideDirection,
                        onPeriodChanged: _onPeriodChanged,
                        onSwipe: _changePeriodBySwipe,
                        onCategoryTap: _openCategoryDetails,
                        onRefresh: _viewModel.refreshAll,
                        translations: tr,
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showFabLabel,
        builder: (context, showLabel, child) => BudglyFab(
          heroTag: 'create_expense',
          label: showLabel ? tr.fabNewExpense : null,
          onPressed: _openAddExpenseModal,
        ),
      ),
    );
  }
}
