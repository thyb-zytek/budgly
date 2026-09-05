import 'dart:async';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/pages/category_expenses/ui_state.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/calculators/expense_summary_calculator.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_form_controller.dart';
import 'package:flutter/material.dart';
import 'package:budgly/src/pages/category_expenses/paged_expenses_state.dart';

class CategoryExpensesViewModel extends BaseViewModel {
  final ExpensesService _expensesService;
  final CategoriesService _categoriesService;
  final ProfileService _profileService;
  final AccountsService _accountsService;
  final ExpenseSummaryCalculator _summaryCalculator;
  final ExpenseOccurrenceCalculator _occurrenceCalculator;

  final String accountId;
  final String categoryId;
  final Period period;

  CategoryExpensesUiState _uiState = const CategoryExpensesUiState();

  final ExpenseFormController expenseForm = ExpenseFormController();

  final _pagedState = PagedExpensesState();
  List<ExpenseOccurrence>? _cachedOccurrences;
  int _occurrencesRevision = 0;
  int _cachedOccurrencesRevision = -1;

  CategoryExpensesViewModel({
    required this.accountId,
    required this.categoryId,
    required this.period,
    ExpensesService? expensesService,
    CategoriesService? categoriesService,
    ProfileService? profileService,
    AccountsService? accountsService,
    ExpenseSummaryCalculator? summaryCalculator,
    ExpenseOccurrenceCalculator? occurrenceCalculator,
  }) : _expensesService = expensesService ?? ExpensesService.instance,
       _categoriesService = categoriesService ?? CategoriesService.instance,
       _profileService = profileService ?? ProfileService.instance,
       _accountsService = accountsService ?? AccountsService.instance,
       _summaryCalculator =
           summaryCalculator ?? const ExpenseSummaryCalculator(),
       _occurrenceCalculator =
           occurrenceCalculator ?? const ExpenseOccurrenceCalculator() {
    expenseForm.addListener(_onFormChanged);
    _expensesService.addListener(_onExpensesChanged);
    _profileService.addListener(_onProfileChanged);
    AnalyticsService.instance.track('screen_viewed', {
      'screen': 'category_expenses',
    });
  }

  void _onFormChanged() => _notifyAfterFrame();

  void _onExpensesChanged() {
    _bumpDataRevision();
    _refreshEditingOccurrence();
    _notifyAfterFrame();
  }

  bool _notificationScheduled = false;

  void _notifyAfterFrame() {
    if (isDisposed || _notificationScheduled) return;
    _notificationScheduled = true;
    scheduleMicrotask(() {
      _notificationScheduled = false;
      if (!isDisposed) notifyListeners();
    });
  }

  void _onProfileChanged() => _notifyAfterFrame();

  void _bumpDataRevision() {
    _occurrencesRevision++;
    _cachedOccurrences = null;
    _cachedOccurrencesRevision = -1;
  }

  void _refreshEditingOccurrence() {
    final current = _uiState.editingOccurrence;
    if (current == null) return;
    final fresh = _expensesService.getExpenseById(current.id);
    if (fresh == null) return;
    _uiState = _uiState.copyWith(
      editingOccurrence: ExpenseOccurrence(
        expense: fresh,
        date: current.date,
        isDebited: fresh.isDebitedAt(current.date),
      ),
    );
  }

  Category? get category => _categoriesService.getCategoryById(categoryId);

  String get currencyCode => _profileService.currency;
  String get localeName => _profileService.locale.languageCode;

  int get amountDecimalPlaces => _profileService.amountDecimalPlaces;

  Color? get accountColor => _accountsService.getAccountById(accountId)?.color;

  CategoryExpensesUiState get uiState => _uiState;
  bool get isSaving => _uiState.isSaving;
  bool get hasMorePages => _pagedState.hasMore;
  bool get isLoadingMore => _pagedState.isLoading;

  ExpenseOccurrence? get editingOccurrence => _uiState.editingOccurrence;
  Future<void> ensureDataLoaded() async {
    if (!_categoriesService.hasLoadedAccount(accountId)) {
      setLoading(true);
      try {
        await _categoriesService.listCategoriesByAccount(accountId);
      } catch (e, stackTrace) {
        setError(e, stackTrace: stackTrace);
      } finally {
        setLoading(false);
      }
    }
    if (!_pagedState.hasLoadedFirstPage) {
      await loadMore();
    }
    if (!isDisposed) notifyListeners();
  }

  Future<void> loadMore() async {
    if (_pagedState.isLoading || !_pagedState.hasMore) return;
    final isFirstPage = !_pagedState.hasLoadedFirstPage;
    _pagedState.isLoading = true;
    if (isFirstPage) setLoading(true);
    if (!isDisposed) notifyListeners();

    try {
      final page = await _expensesService.listCategoryPeriodPage(
        accountId,
        categoryId,
        period,
        startAfter: _pagedState.cursor,
        includeRecurring: !_pagedState.hasLoadedFirstPage,
      );
      _pagedState.append(page.expenses);
      _pagedState.cursor = page.cursor;
      _pagedState.hasMore = page.hasMore;
      _pagedState.hasLoadedFirstPage = true;
      _bumpDataRevision();
    } catch (e, stackTrace) {
      if (isFirstPage) {
        // Offline: fall back to the locally-cached expenses for this category
        // so the list is not empty until a manual refresh succeeds.
        final local = _expensesService
            .getExpensesForAccount(accountId)
            .where((expense) => expense.categoryId == categoryId)
            .toList();
        if (local.isNotEmpty) {
          _pagedState.expenses.addAll(local);
          _pagedState.expenses.sort((a, b) => b.debitDate.compareTo(a.debitDate));
          _pagedState.hasLoadedFirstPage = true;
          _pagedState.hasMore = false;
          _occurrencesRevision++;
        } else {
          setError(e, stackTrace: stackTrace);
        }
      } else {
        // Avoid spamming a snackbar on every scroll-triggered pagination
        // retry over a flaky connection — the user can just keep scrolling
        // to retry, and hasMorePages stays true so nothing is lost.
        AppLogger.error('Failed to load expense page', e, stackTrace);
      }
    } finally {
      _pagedState.isLoading = false;
      AnalyticsService.instance.track('expense_page_loaded', {
        'source': 'pagination',
      });
      if (isFirstPage) {
        setLoading(false);
      } else if (!isDisposed) {
        notifyListeners();
      }
    }
  }

  List<ExpenseOccurrence> get occurrences {
    if (_pagedState.expenses.isEmpty) return const [];
    if (_cachedOccurrencesRevision == _occurrencesRevision &&
        _cachedOccurrences != null) {
      return _cachedOccurrences!;
    }

    final result = _occurrenceCalculator.between(
      _pagedState.expenses,
      period.startOfMonth,
      period.endOfMonth,
    );
    // The shared occurrence calculator keeps its chronological ordering for
    // calculations. The category expense screen presents the most recent
    // occurrence first, matching the paginated expense list.
    result.sort((a, b) {
      if (a.isDebited != b.isDebited) return a.isDebited ? 1 : -1;
      return b.date.compareTo(a.date);
    });
    _cachedOccurrences = result;
    _cachedOccurrencesRevision = _occurrencesRevision;
    return result;
  }

  CategoryExpenseSummary? get summary {
    if (category == null) return null;
    return summarize(occurrences);
  }

  CategoryExpenseSummary summarize(List<ExpenseOccurrence> occurrences) {
    final cat = category;
    if (cat == null) {
      throw StateError('Category is not available');
    }
    return _summaryCalculator.summarize(
      category: cat,
      occurrences: occurrences,
    );
  }

  void startEditing(ExpenseOccurrence occurrence) {
    AnalyticsService.instance.track('category_expense_tap');
    _uiState = _uiState.copyWith(editingOccurrence: occurrence);
    expenseForm.loadFromOccurrence(
      occurrence,
      category: _categoriesService.getCategoryById(occurrence.categoryId),
      account: _accountsService.getAccountById(occurrence.expense.accountId),
    );
  }

  List<Category> categoriesForAccount() {
    final formAccountId = expenseForm.data.account?.id ?? accountId;
    return _categoriesService.getCategoriesForAccount(formAccountId);
  }

  List<Account> get formAccounts => _accountsService.accounts;

  Future<void> selectFormAccount(Account account) async {
    if (expenseForm.data.account?.id == account.id) return;
    expenseForm.setAccount(account);
    if (account.id != null &&
        !_categoriesService.hasLoadedAccount(account.id!)) {
      await _categoriesService.listCategoriesByAccount(account.id!);
    }
    final categories = categoriesForAccount();
    if (categories.isNotEmpty) {
      if (expenseForm.data.category == null ||
          !categories.any((c) => c.id == expenseForm.data.category!.id)) {
        expenseForm.setCategory(categories.first);
      }
    } else {
      expenseForm.data.category = null;
      expenseForm.notifyListeners();
    }
  }

  void selectFormCategory(Category category) {
    expenseForm.setCategory(category);
  }

  Future<bool> saveEditing() async {
    if (_uiState.isSaving) return false;
    final occurrence = _uiState.editingOccurrence;
    if (occurrence == null) return false;

    final amount = expenseForm.parseEnteredAmount();
    if (amount == null) return false;

    _uiState = _uiState.copyWith(isSaving: true);
    if (!isDisposed) notifyListeners();

    try {
      final updated = occurrence.expense.copyWith(
        accountId: expenseForm.data.account?.id ?? occurrence.expense.accountId,
        categoryId: expenseForm.data.category?.id ?? occurrence.expense.categoryId,
        name: expenseForm.data.nameController.text.trim(),
        amount: amount,
        debitDate: expenseForm.data.debitDate,
        endDate: expenseForm.data.effectiveEndDate,
        clearEndDate: expenseForm.data.effectiveEndDate == null,
        recurrence: expenseForm.data.recurrence,
      );

      final moved =
          updated.accountId != occurrence.expense.accountId ||
          updated.categoryId != occurrence.expense.categoryId;
      final savedExpense = occurrence.expense.isRecurring
          ? await _expensesService.updateRecurringExpenseFromOccurrence(
              original: occurrence.expense,
              updated: updated,
              effectiveDate: occurrence.date,
            )
          : await _expensesService.updateExpense(updated, previous: occurrence.expense);
      if (moved) {
        _removePagedExpenseWhenMoved(
          occurrence.expense,
          savedExpense,
        );
      } else if (occurrence.expense.isRecurring &&
          savedExpense.id != occurrence.expense.id &&
          occurrence.expense.id != null &&
          savedExpense.id != null) {
        // The recurring series was split into two expenses — reflect BOTH in
        // the local page list by replacing the original with its versions, so
        // the card updates without leaving and re-entering the screen.
        final previous = _expensesService.getExpenseById(
          occurrence.expense.id!,
        );
        final next = _expensesService.getExpenseById(savedExpense.id!);
        if (previous != null && next != null) {
          _replacePagedExpenseWithSplit(
            occurrence.expense.id!,
            previous,
            next,
          );
        }
      } else {
        _replacePagedExpense(occurrence.expense.id, savedExpense);
      }
      return true;
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
      return false;
    } finally {
      _uiState = _uiState.copyWith(isSaving: false);
      if (!isDisposed) notifyListeners();
    }
  }

  void _replacePagedExpense(String? expenseId, Expense updatedExpense) {
    if (expenseId == null) return;
    var didChange = false;
    final editingOccurrence = _uiState.editingOccurrence;
    if (editingOccurrence?.expense.id == expenseId) {
      _uiState = _uiState.copyWith(
        editingOccurrence: ExpenseOccurrence(
          expense: updatedExpense,
          date: editingOccurrence!.date,
          isDebited: updatedExpense.isDebitedAt(editingOccurrence.date),
        ),
      );
      didChange = true;
    }

    final index = _pagedState.expenses.indexWhere(
      (expense) => expense.id == expenseId,
    );
    if (index != -1) {
      _pagedState.expenses[index] = updatedExpense;
      _pagedState.expenses.sort((a, b) => b.debitDate.compareTo(a.debitDate));
      didChange = true;
    }
    if (didChange) {
      _bumpDataRevision();
    }
  }

  void _replacePagedExpenseWithSplit(
    String expenseId,
    Expense previous,
    Expense next,
  ) {
    _pagedState.expenses.removeWhere((expense) => expense.id == expenseId);
    _pagedState.expenses.add(previous);
    _pagedState.expenses.add(next);
    _pagedState.expenses.sort((a, b) => b.debitDate.compareTo(a.debitDate));
    _bumpDataRevision();
  }

  void _removePagedExpenseWhenMoved(Expense original, Expense savedExpense) {
    final before = _pagedState.expenses.length;
    _pagedState.expenses.removeWhere(
      (expense) =>
          expense.id == original.id || expense.id == savedExpense.id,
    );
    if (_pagedState.expenses.length != before) {
      _uiState = _uiState.copyWith(
        clearEditingOccurrence:
            _uiState.editingOccurrence?.expense.id == original.id,
      );
    }
  }

  Future<bool> deleteEditingExpense() async {
    final occurrence = _uiState.editingOccurrence;
    if (occurrence == null) return false;
    return deleteOccurrence(occurrence);
  }

  Future<bool> deleteOccurrence(ExpenseOccurrence occurrence) async {
    if (_uiState.isSaving) return false;
    if (occurrence.id.isEmpty) return false;
    if (occurrence.recurrence.isRecurring) {
      return deleteSingleOccurrence(occurrence);
    }

    _uiState = _uiState.copyWith(isSaving: true);
    if (!isDisposed) notifyListeners();

    try {
      final success =
          await _expensesService.deleteExpense(occurrence.id, accountId);
      if (success) {
        _pagedState.expenses.removeWhere((expense) => expense.id == occurrence.id);
        _uiState = _uiState.copyWith(
          clearEditingOccurrence:
              _uiState.editingOccurrence?.id == occurrence.id,
          );
      }
      return success;
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
      return false;
    } finally {
      _uiState = _uiState.copyWith(isSaving: false);
      if (!isDisposed) notifyListeners();
    }
  }

  Future<bool> deleteSingleOccurrence(ExpenseOccurrence occurrence) async {
    if (_uiState.isSaving) return false;
    if (occurrence.id.isEmpty) return false;

    _uiState = _uiState.copyWith(isSaving: true);
    if (!isDisposed) notifyListeners();

    try {
      final success = await _expensesService.deleteSingleOccurrence(
        expense: occurrence.expense,
        occurrenceDate: occurrence.date,
      );
      if (success) {
        _syncPagedAfterRecurringDelete(occurrence);
      }
      return success;
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
      return false;
    } finally {
      _uiState = _uiState.copyWith(isSaving: false);
      if (!isDisposed) notifyListeners();
    }
  }

  Future<bool> deleteFutureOccurrences(ExpenseOccurrence occurrence) async {
    if (_uiState.isSaving) return false;
    if (occurrence.id.isEmpty) return false;

    _uiState = _uiState.copyWith(isSaving: true);
    if (!isDisposed) notifyListeners();

    try {
      final success = await _expensesService.deleteFutureOccurrences(
        expense: occurrence.expense,
        occurrenceDate: occurrence.date,
      );
      if (success) {
        _syncPagedAfterRecurringDelete(occurrence);
      }
      return success;
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
      return false;
    } finally {
      _uiState = _uiState.copyWith(isSaving: false);
      if (!isDisposed) notifyListeners();
    }
  }

  void _syncPagedAfterRecurringDelete(ExpenseOccurrence occurrence) {
    final updated = _expensesService.getExpenseById(occurrence.id);

    if (updated == null) {
      _pagedState.expenses.removeWhere((e) => e.id == occurrence.id);
      _uiState = _uiState.copyWith(
        clearEditingOccurrence: _uiState.editingOccurrence?.id == occurrence.id,
      );
      return;
    }

    final index = _pagedState.expenses.indexWhere((e) => e.id == occurrence.id);
    if (index != -1) {
      _pagedState.expenses[index] = updated;
      // If this was a split (single deletion not first with future), the
      // new tail expense was added to the store with a new id.
      // We need to add it to the paged list if it belongs to this period/category.
      // Find any new expense that wasn't in the list.
      for (final expense in _expensesService
          .getExpensesForAccount(updated.accountId)) {
        if (expense.id != null &&
            !_pagedState.expenses.any((e) => e.id == expense.id) &&
            expense.categoryId == categoryId &&
            expense.accountId == accountId) {
          // Only add if the expense overlaps the current period.
          final start = period.startOfMonth;
          final end = period.endOfMonth;
          final endOfExpense = expense.endOfEndDate;
          final overlaps = !expense.debitDate.isAfter(end) &&
              (endOfExpense == null || !endOfExpense.isBefore(start));
          if (overlaps) {
            _pagedState.expenses.add(expense);
          }
        }
      }
      _pagedState.expenses.sort((a, b) => b.debitDate.compareTo(a.debitDate));
    }

    _occurrencesRevision++;
    _cachedOccurrences = null;
    _cachedOccurrencesRevision = -1;
    _uiState = _uiState.copyWith(
      clearEditingOccurrence: _uiState.editingOccurrence?.id == occurrence.id &&
          updated.id != occurrence.id,
    );
    if (_pagedState.expenses.any((e) => e.id == updated.id) == false &&
        _uiState.editingOccurrence?.id == occurrence.id) {
      _uiState = _uiState.copyWith(clearEditingOccurrence: true);
    }
  }

  Future<bool> toggleEditingOccurrenceDebited() async {
    final occurrence = _uiState.editingOccurrence;
    if (occurrence == null) return false;
    return toggleDebited(occurrence);
  }

  Future<bool> toggleDebited(ExpenseOccurrence occurrence) async {
    if (_uiState.isSaving) return false;
    _uiState = _uiState.copyWith(isSaving: true);
    if (!isDisposed) notifyListeners();

    try {
      final updatedExpense = await _expensesService.toggleOccurrenceDebited(
        occurrence.expense,
        occurrence.date,
      );
      _replacePagedExpense(occurrence.expense.id, updatedExpense);
      return true;
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
      return false;
    } finally {
      _uiState = _uiState.copyWith(isSaving: false);
      if (!isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _expensesService.removeListener(_onExpensesChanged);
    _profileService.removeListener(_onProfileChanged);
    expenseForm.removeListener(_onFormChanged);
    expenseForm.dispose();
    super.dispose();
  }
}
