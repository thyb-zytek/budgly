import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/pages/category_expenses/category_expenses_provider.dart';
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
import 'package:budgly/src/shared/ui/widgets/feedback/riverpod_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_form_controller.dart';

class CategoryExpensesPage extends ConsumerStatefulWidget {
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
  ConsumerState<CategoryExpensesPage> createState() =>
      _CategoryExpensesPageState();
}

class _CategoryExpensesPageState extends ConsumerState<CategoryExpensesPage> {
  final GlobalKey<SwipeHintWrapperState> _swipeHintKey =
      GlobalKey<SwipeHintWrapperState>();
  final ScrollController _scrollController = ScrollController();

  late final ExpenseFormController _expenseForm;

  CategoryExpensesState get _state => ref.read(
    categoryExpensesProvider(
      widget.accountId,
      widget.categoryId,
      widget.period,
    ),
  );
  CategoryExpenses get _notifier => ref.read(
    categoryExpensesProvider(
      widget.accountId,
      widget.categoryId,
      widget.period,
    ).notifier,
  );

  @override
  void initState() {
    super.initState();
    _expenseForm = ExpenseFormController();
    Future.microtask(() => _notifier.ensureDataLoaded());
    _scrollController.addListener(_onScroll);
  }

  List<Account> get _formAccounts => ref.read(accountsSessionProvider).accounts;

  List<Category> get _formCategories {
    final accountId = _expenseForm.data.account?.id ?? widget.accountId;
    return ref.read(categoriesSessionProvider).categoriesByAccount[accountId] ??
        const [];
  }

  Future<void> _selectFormAccount(Account account) async {
    if (_expenseForm.data.account?.id == account.id) return;
    _expenseForm.setAccount(account);
    if (account.id != null) {
      final session = ref.read(categoriesSessionProvider);
      if (!session.loadedAccounts.contains(account.id!)) {
        await ref.read(categoriesSessionProvider.notifier).load(account.id!);
      }
    }
    final categories = _formCategories;
    if (categories.isNotEmpty) {
      if (_expenseForm.data.category == null ||
          !categories.any(
            (category) => category.id == _expenseForm.data.category!.id,
          )) {
        _expenseForm.setCategory(categories.first);
      }
    } else {
      _expenseForm.clearCategory();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 500) _notifier.loadMore();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _expenseForm.dispose();
    super.dispose();
  }

  Future<void> _openEditSheet(ExpenseOccurrence occurrence) async {
    final tr = AppLocalizations.of(context)!;
    _notifier.startEditing(occurrence);
    final category = ref
        .read(categoriesSessionProvider)
        .categoriesByAccount[occurrence.expense.accountId]
        ?.where((item) => item.id == occurrence.categoryId)
        .firstOrNull;
    final account = ref
        .read(accountsSessionProvider)
        .accounts
        .where((item) => item.id == occurrence.expense.accountId)
        .firstOrNull;
    _expenseForm.loadFromOccurrence(
      occurrence,
      category: category,
      account: account,
    );
    showAppBottomSheet(
      context,
      builder: (context) => ExpenseEditorSheet(
        listenable: _expenseForm,
        editingData: _expenseForm.data,
        nameController: _expenseForm.nameController,
        amountController: _expenseForm.amountController,
        title: tr.editExpense,
        currencyCode: _state.currencyCode,
        localeName: _state.localeName,
        validate: (tr) =>
            _expenseForm.validate(tr, requireAccountAndCategory: true),
        onSubmit: () {
          final amount = _expenseForm.parseEnteredAmount();
          if (amount == null) return Future.value(false);
          return _notifier.saveEditing(
            ExpenseEditFormData(
              name: _expenseForm.nameController.text.trim(),
              amount: amount,
              categoryId: _expenseForm.data.category?.id,
              debitDate: _expenseForm.data.debitDate,
              endDate: _expenseForm.data.effectiveEndDate,
              recurrence: _expenseForm.data.recurrence,
            ),
          );
        },
        onBeforeSubmit: occurrence.recurrence.isRecurring
            ? () async {
                final choice = await showRecurringEditOptions(
                  context,
                  expenseName: occurrence.name,
                  dateLabel: DateFormat.yMMMMd(
                    _state.localeName,
                  ).format(occurrence.date),
                );
                if (!mounted || choice == null) return false;
                _notifier.setRecurringEditScope(
                  choice == RecurringEditChoice.single
                      ? RecurringEditScope.single
                      : RecurringEditScope.future,
                );
                return true;
              }
            : null,
        submitFailureMessage: tr.expenseUpdateFailed,
        onToggleAdvanced: _expenseForm.toggleAdvancedOptions,
        onDateChanged: _expenseForm.setDebitDate,
        onRecurrenceChanged: _expenseForm.setRecurrence,
        onEndDateChanged: _expenseForm.setEndDate,
        onEndDateCleared: _expenseForm.clearEndDate,
        isSubmitEnabled: () =>
            _formCategories.isNotEmpty &&
            _expenseForm.data.account != null &&
            _expenseForm.data.category != null,
        titleLeadingBuilder: (context) {
          final occ = _state.editingOccurrence;
          if (occ == null) return const SizedBox(width: 40);
          final theme = Theme.of(context);
          return IconButton.filled(
            style: ButtonType.error.iconFilledStyle(theme),
            onPressed: _state.isSaving ? null : _deleteEditingExpense,
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: tr.delete,
          );
        },
        titleTrailingBuilder: (context) {
          final occ = _state.editingOccurrence;
          if (occ == null) return const SizedBox(width: 40);
          final theme = Theme.of(context);
          final isDebited = occ.isDebited;
          return IconButton.filled(
            style: (isDebited ? ButtonType.secondary : ButtonType.success)
                .iconFilledStyle(theme),
            onPressed: _state.isSaving ? null : _toggleEditingDebited,
            icon: Icon(
              isDebited
                  ? Icons.remove_circle_outline
                  : Icons.check_circle_outline,
              size: 20,
            ),
            tooltip: isDebited ? tr.expenseMarkedAsPending : tr.markAsDebited,
          );
        },
        preFieldsBuilder: (context) {
          final theme = Theme.of(context);
          final occ = _state.editingOccurrence;
          final categories = _formCategories;
          final accounts = _formAccounts;
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
                      selectedAccount: _expenseForm.data.account,
                      backgroundColor: theme.colorScheme.surface,
                      onSelect: _selectFormAccount,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            spacing: 8,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
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
                            selectedCategory: _expenseForm.data.category,
                            onSelect: _expenseForm.setCategory,
                          ),
                        ),
                ],
              ),
              if (occ != null && occ.recurrence.isRecurring)
                Text(
                  tr.recurringEditFromDate(
                    DateFormat.yMMMMd(_state.localeName).format(occ.date),
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (occ != null && occ.recurrence.isRecurring)
                Text(
                  tr.markDebitedOccurrence(
                    DateFormat.yMMMMd(_state.localeName).format(occ.date),
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
    final wasDebited = _state.editingOccurrence?.isDebited ?? false;
    final success = await _notifier.toggleEditingOccurrenceDebited();
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
    final occurrence = _state.editingOccurrence;
    if (occurrence == null) return;

    var success = false;
    bool? confirmed;

    if (occurrence.recurrence.isRecurring) {
      final choice = await showRecurringDeleteOptions(
        context,
        expenseName: occurrence.name,
        dateLabel: DateFormat.yMMMMd(_state.localeName).format(occurrence.date),
      );
      if (choice == null) return;
      if (choice == RecurringDeleteChoice.single) {
        success = await _notifier.deleteSingleOccurrence(occurrence);
        confirmed = success;
      } else {
        success = await _notifier.deleteFutureOccurrences(occurrence);
        confirmed = success;
      }
    } else {
      confirmed = await showConfirmDelete(
        context,
        title: tr.confirmDeleteExpense(occurrence.name),
        content: tr.confirmDeleteExpenseMessage(occurrence.name),
        onConfirm: () async {
          success = await _notifier.deleteEditingExpense();
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

    final success = await _notifier.toggleDebited(occurrence);
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
        dateLabel: DateFormat.yMMMMd(_state.localeName).format(occurrence.date),
      );
      if (choice == null) return;
      if (choice == RecurringDeleteChoice.single) {
        success = await _notifier.deleteSingleOccurrence(occurrence);
      } else {
        success = await _notifier.deleteFutureOccurrences(occurrence);
      }
    } else {
      final deleted = await showConfirmDelete(
        context,
        title: tr.confirmDeleteExpense(occurrence.name),
        content: tr.confirmDeleteExpenseMessage(occurrence.name),
        onConfirm: () async {
          success = await _notifier.deleteOccurrence(occurrence);
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
    final state = ref.watch(
      categoryExpensesProvider(
        widget.accountId,
        widget.categoryId,
        widget.period,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.category?.name ?? '',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: RiverpodFeedback(
        messageListenable: categoryExpensesProvider(
          widget.accountId,
          widget.categoryId,
          widget.period,
        ).select((state) => state.status.pendingMessage),
        onConsume: (ref) => ref
            .read(
              categoryExpensesProvider(
                widget.accountId,
                widget.categoryId,
                widget.period,
              ).notifier,
            )
            .consumeMessage(),
        child: state.isLoading || state.category == null
            ? const AppLoadingIndicator()
            : CategoryExpensesContent(
                state: state,
                translations: tr,
                swipeHintKey: _swipeHintKey,
                onEdit: _openEditSheet,
                onToggleDebited: _toggleDebited,
                onDelete: _deleteOccurrence,
                scrollController: _scrollController,
              ),
      ),
    );
  }
}
