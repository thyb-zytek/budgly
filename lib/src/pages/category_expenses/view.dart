import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/view_models/view_model_selector.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/pages/category_expenses/view_model.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_editor_sheet.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/domain/widgets/categories/selector.dart';
import 'package:budgly/src/shared/ui/widgets/layout/framed_container.dart';
import 'package:budgly/src/shared/ui/widgets/layout/section_label.dart';
import 'package:intl/intl.dart';
import 'package:budgly/src/pages/category_expenses/widgets/swipe_hint_wrapper.dart';
import 'package:budgly/src/pages/category_expenses/widgets/category_expenses_content.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/view_model_feedback.dart';
import 'package:flutter/material.dart';

class CategoryExpensesPage extends StatefulWidget {
  final String accountId;
  final String categoryId;
  final Period period;
  final CategoryExpensesViewModel? injectedViewModel;

  const CategoryExpensesPage({
    super.key,
    required this.accountId,
    required this.categoryId,
    required this.period,
    this.injectedViewModel,
  });

  @override
  State<CategoryExpensesPage> createState() => _CategoryExpensesPageState();
}

class _CategoryExpensesPageState extends State<CategoryExpensesPage> {
  final GlobalKey<SwipeHintWrapperState> _swipeHintKey =
      GlobalKey<SwipeHintWrapperState>();
  final ScrollController _scrollController = ScrollController();

  late final CategoryExpensesViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.injectedViewModel == null;
    _viewModel = widget.injectedViewModel ??
        CategoryExpensesViewModel(
          accountId: widget.accountId,
          categoryId: widget.categoryId,
          period: widget.period,
        );
    _viewModel.ensureDataLoaded();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 500) {
      _viewModel.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  void _openEditSheet(ExpenseOccurrence occurrence) {
    final tr = AppLocalizations.of(context)!;
    _viewModel.startEditing(occurrence);
    showAppBottomSheet(
      context,
      builder: (context) => ExpenseEditorSheet(
        listenable: _viewModel,
        editingData: _viewModel.expenseForm.data,
        title: tr.editExpense,
        currencyCode: _viewModel.currencyCode,
        localeName: _viewModel.localeName,
        validate: (tr) => _viewModel.expenseForm.validate(tr, requireAccountAndCategory: true),
        onSubmit: _viewModel.saveEditing,
        submitFailureMessage: tr.expenseUpdateFailed,
        onToggleAdvanced: _viewModel.expenseForm.toggleAdvancedOptions,
        onDateChanged: _viewModel.expenseForm.setDebitDate,
        onRecurrenceChanged: _viewModel.expenseForm.setRecurrence,
        onEndDateChanged: _viewModel.expenseForm.setEndDate,
        onEndDateCleared: _viewModel.expenseForm.clearEndDate,
        isSaving: () => _viewModel.isSaving,
        isSubmitEnabled: () => _viewModel.categoriesForAccount().isNotEmpty &&
            _viewModel.expenseForm.data.account != null &&
            _viewModel.expenseForm.data.category != null,
        titleLeadingBuilder: (context) {
          final occ = _viewModel.editingOccurrence;
          if (occ == null) return const SizedBox(width: 40);
          final scheme = Theme.of(context).colorScheme;
          return IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _viewModel.isSaving ? null : _deleteEditingExpense,
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: tr.delete,
          );
        },
        titleTrailingBuilder: (context) {
          final occ = _viewModel.editingOccurrence;
          if (occ == null) return const SizedBox(width: 40);
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final isDebited = occ.isDebited;
          final successColors = ButtonType.success.colors(theme);
          return IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: isDebited ? scheme.secondary : successColors.background,
              foregroundColor: isDebited ? scheme.onSecondary : successColors.foreground,
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _viewModel.isSaving ? null : _toggleEditingDebited,
            icon: Icon(
              isDebited ? Icons.remove_circle_outline : Icons.check_circle_outline,
              size: 20,
            ),
            tooltip: isDebited ? tr.expenseMarkedAsPending : tr.markAsDebited,
          );
        },
        preFieldsBuilder: (context) {
          final theme = Theme.of(context);
          final occ = _viewModel.editingOccurrence;
          final categories = _viewModel.categoriesForAccount();
          final accounts = _viewModel.formAccounts;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  SectionLabel(tr.account),
                  FramedContainer(
                    child: AccountSelector(
                      accounts: accounts,
                      selectedAccount: _viewModel.expenseForm.data.account,
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
                            selectedCategory: _viewModel.expenseForm.data.category,
                            onSelect: _viewModel.selectFormCategory,
                          ),
                        ),
                ],
              ),
              if (occ != null && occ.recurrence.isRecurring)
                Text(
                  tr.recurringEditFromDate(
                    DateFormat.yMMMMd(_viewModel.localeName).format(occ.date),
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (occ != null && occ.recurrence.isRecurring)
                Text(
                  tr.markDebitedOccurrence(
                    DateFormat.yMMMMd(_viewModel.localeName).format(occ.date),
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          );
        },
        onSubmitSuccess: () {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(
            buildAppSnackBar(
              tr.expenseUpdatedSuccessfully,
              SnackBarType.success,
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleEditingDebited() async {
    final tr = AppLocalizations.of(context)!;
    final wasDebited = _viewModel.editingOccurrence?.isDebited ?? false;
    final success = await _viewModel.toggleEditingOccurrenceDebited();
    if (!mounted || !success) return;

    showAppSnackBar(
      context,
      message: wasDebited
          ? tr.expenseMarkedAsPending
          : tr.expenseMarkedAsDebited,
      type: wasDebited ? SnackBarType.pending : SnackBarType.success,
    );
  }

  Future<void> _deleteEditingExpense() async {
    final tr = AppLocalizations.of(context)!;
    final occurrence = _viewModel.editingOccurrence;
    if (occurrence == null) return;

    var success = false;
    bool? confirmed;

    if (occurrence.recurrence.isRecurring) {
      final choice = await showRecurringDeleteOptions(
        context,
        expenseName: occurrence.name,
        dateLabel: DateFormat.yMMMMd(_viewModel.localeName).format(occurrence.date),
      );
      if (choice == null) return;
      if (choice == RecurringDeleteChoice.single) {
        success = await _viewModel.deleteSingleOccurrence(occurrence);
        confirmed = success;
      } else {
        success = await _viewModel.deleteFutureOccurrences(occurrence);
        confirmed = success;
      }
    } else {
      confirmed = await showConfirmDelete(
        context,
        title: tr.confirmDeleteExpense(occurrence.name),
        content: tr.confirmDeleteExpenseMessage(occurrence.name),
        onConfirm: () async {
          success = await _viewModel.deleteEditingExpense();
        },
      );
      if (confirmed != true) return;
    }

    if (!mounted || !success) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      buildAppSnackBar(tr.expenseDeletedSuccessfully, SnackBarType.success),
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
      type: wasDebited ? SnackBarType.pending : SnackBarType.success,
    );
  }

  Future<void> _deleteOccurrence(ExpenseOccurrence occurrence) async {
    final tr = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    var success = false;

    if (occurrence.recurrence.isRecurring) {
      final choice = await showRecurringDeleteOptions(
        context,
        expenseName: occurrence.name,
        dateLabel: DateFormat.yMMMMd(_viewModel.localeName).format(occurrence.date),
      );
      if (choice == null) return;
      if (choice == RecurringDeleteChoice.single) {
        success = await _viewModel.deleteSingleOccurrence(occurrence);
      } else {
        success = await _viewModel.deleteFutureOccurrences(occurrence);
      }
    } else {
      final deleted = await showConfirmDelete(
        context,
        title: tr.confirmDeleteExpense(occurrence.name),
        content: tr.confirmDeleteExpenseMessage(occurrence.name),
        onConfirm: () async {
          success = await _viewModel.deleteOccurrence(occurrence);
        },
      );
      if (deleted != true) return;
    }

    if (!mounted || !success) return;

    messenger.showSnackBar(
      buildAppSnackBar(tr.expenseDeletedSuccessfully, SnackBarType.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: ViewModelSelector<CategoryExpensesViewModel, String>(
          model: _viewModel,
          selector: (model) => model.category?.name ?? '',
          builder: (context, name) => Text(
            name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: ViewModelFeedback(
        viewModel: _viewModel,
        child: ViewModelSelector<CategoryExpensesViewModel, bool>(
        model: _viewModel,
        selector: (model) => model.isLoading,
        builder: (context, isLoading) {
          if (isLoading || _viewModel.category == null) {
            return const AppLoadingIndicator();
          }

          return ViewModelSelector<CategoryExpensesViewModel, (
            List<ExpenseOccurrence>,
            bool,
            Category?,
            String,
            String,
            int,
            Color?,
          )>(
            model: _viewModel,
            selector: (model) => (
              model.occurrences,
              model.isLoadingMore,
              model.category,
              model.currencyCode,
              model.localeName,
              model.amountDecimalPlaces,
              model.accountColor,
            ),
            builder: (context, _) => CategoryExpensesContent(
              viewModel: _viewModel,
              translations: tr,
              swipeHintKey: _swipeHintKey,
              onEdit: _openEditSheet,
              onToggleDebited: _toggleDebited,
              onDelete: _deleteOccurrence,
              scrollController: _scrollController,
            ),
          );
        },
        ),
      ),
    );
  }
}
