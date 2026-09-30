import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/state/action_status.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:budgly/src/services/calculators/expense_summary_calculator.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_expenses_provider.g.dart';

enum RecurringEditScope { single, future }

@immutable
class CategoryExpensesState {
  const CategoryExpensesState({
    required this.category,
    required this.accountColor,
    required this.currencyCode,
    required this.localeName,
    required this.amountDecimalPlaces,
    required this.occurrences,
    required this.hasMorePages,
    required this.isLoadingMore,
    required this.editingOccurrence,
    required this.isSaving,
    required this.status,
  });

  const CategoryExpensesState.initial()
    : category = null,
      accountColor = null,
      currencyCode = 'EUR',
      localeName = 'fr',
      amountDecimalPlaces = 2,
      occurrences = const [],
      hasMorePages = true,
      isLoadingMore = false,
      editingOccurrence = null,
      isSaving = false,
      status = const ActionStatus.idle();

  final Category? category;
  final Color? accountColor;
  final String currencyCode;
  final String localeName;
  final int amountDecimalPlaces;
  final List<ExpenseOccurrence> occurrences;
  final bool hasMorePages;
  final bool isLoadingMore;
  final ExpenseOccurrence? editingOccurrence;
  final bool isSaving;
  final ActionStatus status;

  bool get isLoading => status.isLoading;

  CategoryExpenseSummary? get summary {
    final currentCategory = category;
    if (currentCategory == null) return null;
    return const ExpenseSummaryCalculator().summarize(
      category: currentCategory,
      occurrences: occurrences,
    );
  }

  CategoryExpensesState copyWith({
    Category? category,
    Color? accountColor,
    String? currencyCode,
    String? localeName,
    int? amountDecimalPlaces,
    List<ExpenseOccurrence>? occurrences,
    bool? hasMorePages,
    bool? isLoadingMore,
    Object? editingOccurrence = _unset,
    bool? isSaving,
    ActionStatus? status,
  }) {
    return CategoryExpensesState(
      category: category ?? this.category,
      accountColor: accountColor ?? this.accountColor,
      currencyCode: currencyCode ?? this.currencyCode,
      localeName: localeName ?? this.localeName,
      amountDecimalPlaces: amountDecimalPlaces ?? this.amountDecimalPlaces,
      occurrences: occurrences ?? this.occurrences,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      editingOccurrence: identical(editingOccurrence, _unset)
          ? this.editingOccurrence
          : editingOccurrence as ExpenseOccurrence?,
      isSaving: isSaving ?? this.isSaving,
      status: status ?? this.status,
    );
  }
}

const _unset = Object();

@riverpod
class CategoryExpenses extends _$CategoryExpenses {
  late String _accountId;
  late String _categoryId;
  late Period _period;
  late ExpensesService _expensesService;

  final _occurrenceCalculator = const ExpenseOccurrenceCalculator();
  final List<Expense> _expenses = [];

  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasLoadedFirstPage = false;
  RecurringEditScope _editScope = RecurringEditScope.future;

  @override
  CategoryExpensesState build(
    String accountId,
    String categoryId,
    Period period,
  ) {
    _accountId = accountId;
    _categoryId = categoryId;
    _period = period;
    _expensesService = ref.read(expensesServiceProvider);

    ref.listen(expensesSessionProvider, (_, next) {
      if (next.expensesByAccount[accountId] != null) _syncFromExternalChanges();
    });
    ref.listen(profileSessionProvider, (_, next) {
      _refreshProfileFields((
        currency: next.currency,
        localeName: next.locale.languageCode,
        amountDecimalPlaces: next.amountDecimalPlaces,
      ));
    });
    ref.listen(accountsSessionProvider, (_, next) {
      final account = next.accounts
          .where((account) => account.id == accountId)
          .firstOrNull;
      _refreshAccountColor(account?.color);
    });
    ref.listen(categoriesSessionProvider, (_, next) {
      if (next.categoriesByAccount[accountId] != null) _refreshCategoryData();
    });

    // Deferred a microtask so `build()` itself stays a pure state
    // construction function (see the audit reviews of 2026-09-27): a tracking
    // call is a side effect, and Riverpod may re-run `build()` for reasons
    // unrelated to a genuine new screen visit.
    Future.microtask(() {
      if (!ref.mounted) return;
      ref.read(analyticsServiceProvider).track('screen_viewed', {
        'screen': 'category_expenses',
      });
    });

    final profile = ref.read(profileSessionProvider);
    final account = ref
        .read(accountsSessionProvider)
        .accounts
        .where((item) => item.id == _accountId)
        .firstOrNull;
    final category =
        (ref.read(categoriesSessionProvider).categoriesByAccount[_accountId] ??
                const <Category>[])
            .where((item) => item.id == _categoryId)
            .firstOrNull;

    return const CategoryExpensesState.initial().copyWith(
      category: category,
      accountColor: account?.color,
      currencyCode: profile.currency,
      localeName: profile.locale.languageCode,
      amountDecimalPlaces: profile.amountDecimalPlaces,
    );
  }

  void _refreshProfileFields(
    ({String currency, String localeName, int amountDecimalPlaces}) profile,
  ) {
    state = state.copyWith(
      currencyCode: profile.currency,
      localeName: profile.localeName,
      amountDecimalPlaces: profile.amountDecimalPlaces,
    );
  }

  void _refreshAccountColor(Color? color) {
    state = state.copyWith(accountColor: color);
  }

  void _refreshCategoryData() {
    final categories =
        ref.read(categoriesSessionProvider).categoriesByAccount[_accountId] ??
        const <Category>[];
    final category = categories
        .where((item) => item.id == _categoryId)
        .firstOrNull;
    state = state.copyWith(category: category);
  }

  void _syncFromExternalChanges() {
    if (_expenses.isEmpty && !_hasLoadedFirstPage) return;
    var changed = false;
    for (var i = 0; i < _expenses.length; i++) {
      final id = _expenses[i].id;
      if (id == null) continue;
      final fresh = ref
          .read(expensesSessionProvider.notifier)
          .getExpenseById(id);
      // Expense's == only compares the id (see docs/ARCHITECTURE.md), so it
      // can never detect a field-level change here. ExpensesSession always
      // stores a new instance on mutation, so identity is the correct check:
      // it only misses a genuine no-op re-store, which is harmless (an extra
      // rebuild), unlike missing a real edit made elsewhere.
      if (fresh != null && !identical(fresh, _expenses[i])) {
        _expenses[i] = fresh;
        changed = true;
      }
    }
    final editing = state.editingOccurrence;
    if (editing != null && editing.expense.id != null) {
      final fresh = ref
          .read(expensesSessionProvider.notifier)
          .getExpenseById(editing.expense.id!);
      if (fresh != null) {
        state = state.copyWith(
          editingOccurrence: ExpenseOccurrence(
            expense: fresh,
            date: editing.date,
            isDebited: fresh.isDebitedAt(editing.date),
          ),
        );
        changed = true;
      }
    }
    if (changed) {
      _sortExpenses();
      _publishOccurrences();
    }
  }

  Future<void> ensureDataLoaded() async {
    if (!_hasLoadedFirstPage) await loadMore();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMorePages) return;
    final isFirstPage = !_hasLoadedFirstPage;
    state = state.copyWith(
      isLoadingMore: true,
      status: isFirstPage ? state.status.loading() : state.status,
    );
    try {
      final page = await _expensesService.listCategoryPeriodPage(
        _accountId,
        _categoryId,
        _period,
        startAfter: _cursor,
        includeRecurring: isFirstPage,
      );
      if (!ref.mounted) return;
      _appendExpenses(page.expenses);
      _cursor = page.cursor;
      _hasLoadedFirstPage = true;
      state = state.copyWith(hasMorePages: page.hasMore);
      _publishOccurrences();
    } catch (error, stackTrace) {
      if (!ref.mounted) return;
      if (isFirstPage) {
        final local =
            ref
                .read(expensesSessionProvider)
                .expensesByAccount[_accountId]
                ?.where((expense) {
                  if (!expense.isRecurring) {
                    return expense.categoryId == _categoryId;
                  }
                  return _occurrenceCalculator
                      .between([expense], _period.range)
                      .any(
                        (occurrence) => occurrence.categoryId == _categoryId,
                      );
                })
                .toList() ??
            const <Expense>[];
        if (local.isNotEmpty) {
          _appendExpenses(local);
          _hasLoadedFirstPage = true;
          state = state.copyWith(hasMorePages: false);
          _publishOccurrences();
        } else {
          state = state.copyWith(status: state.status.failure(error));
        }
      } else {
        AppLogger.error('Failed to load expense page', error, stackTrace);
      }
    } finally {
      if (ref.mounted) {
        ref.read(analyticsServiceProvider).track('expense_page_loaded', {
          'source': 'pagination',
        });
        state = state.copyWith(
          isLoadingMore: false,
          status: state.status.doneLoading(),
        );
      }
    }
  }

  void _appendExpenses(Iterable<Expense> values) {
    final ids = _expenses.map((e) => e.id).whereType<String>().toSet();
    for (final expense in values) {
      if (expense.id == null || ids.add(expense.id!)) _expenses.add(expense);
    }
    _sortExpenses();
  }

  void _sortExpenses() =>
      _expenses.sort((a, b) => b.debitDate.compareTo(a.debitDate));

  List<ExpenseOccurrence> _calculateOccurrences() {
    if (_expenses.isEmpty) return const [];
    final result = _occurrenceCalculator
        .between(_expenses, _period.range)
        .where((occurrence) => occurrence.categoryId == _categoryId)
        .toList();
    result.sort((a, b) {
      if (a.isDebited != b.isDebited) return a.isDebited ? 1 : -1;
      return b.date.compareTo(a.date);
    });
    return result;
  }

  void _publishOccurrences() {
    state = state.copyWith(
      occurrences: List.unmodifiable(_calculateOccurrences()),
    );
  }

  void consumeMessage() {
    state = state.copyWith(status: state.status.consumeMessage());
  }

  void startEditing(ExpenseOccurrence occurrence) {
    ref.read(analyticsServiceProvider).track('category_expense_tap');
    _editScope = RecurringEditScope.future;
    state = state.copyWith(editingOccurrence: occurrence);
  }

  void setRecurringEditScope(RecurringEditScope scope) => _editScope = scope;

  Future<bool> saveEditing(ExpenseFormData data) async {
    final occurrence = state.editingOccurrence;
    if (state.isSaving || occurrence == null) return false;
    state = state.copyWith(isSaving: true);
    try {
      final updated = occurrence.expense.copyWith(
        accountId: occurrence.expense.accountId,
        categoryId: data.categoryId ?? occurrence.expense.categoryId,
        name: data.name,
        amount: data.amount,
        debitDate: occurrence.expense.debitDate,
        endDate: occurrence.expense.endDate,
        recurrence: occurrence.expense.recurrence,
      );
      final isRecurringSingle =
          occurrence.expense.isRecurring &&
          _editScope == RecurringEditScope.single;
      final moved =
          !occurrence.expense.isRecurring &&
          updated.categoryId != occurrence.expense.categoryId;
      final savedExpense = isRecurringSingle
          ? await _expensesService.modifySingleOccurrence(
              original: occurrence.expense,
              occurrenceDate: occurrence.sourceDate ?? occurrence.date,
              override: updated,
            )
          : occurrence.expense.isRecurring
          ? await _expensesService.modifyFutureOccurrences(
              original: occurrence.expense,
              updated: updated,
              effectiveDate: occurrence.sourceDate ?? occurrence.date,
            )
          : await _expensesService.updateExpense(
              occurrence.expense.copyWith(
                categoryId: data.categoryId ?? occurrence.expense.categoryId,
                name: data.name,
                amount: data.amount,
                debitDate: data.debitDate,
                endDate: data.endDate,
                clearEndDate: data.endDate == null,
                recurrence: data.recurrence,
              ),
              previous: occurrence.expense,
            );
      if (!ref.mounted) return false;

      if (moved) {
        // The expense still exists on the account, just under another
        // category: keep the shared session in sync, only drop it from this
        // page's own (category-scoped) list.
        ref.read(expensesSessionProvider.notifier).updateLocal(savedExpense);
        _removeExpense(occurrence.expense.id);
        state = state.copyWith(editingOccurrence: null);
      } else if (occurrence.expense.isRecurring &&
          savedExpense.id != occurrence.expense.id) {
        // The recurring series was split: the original record was truncated
        // (new endDate) and a new one was created for the future occurrences.
        // We only get the new record back from the service, so refresh the
        // account from the server to also pick up the truncated original
        // rather than guessing its new state.
        await ref
            .read(expensesSessionProvider.notifier)
            .loadAccount(_accountId, forceRefresh: true);
        if (!ref.mounted) return true;
        final previous = ref
            .read(expensesSessionProvider.notifier)
            .getExpenseById(occurrence.expense.id!);
        final next = savedExpense.id == null
            ? null
            : ref
                  .read(expensesSessionProvider.notifier)
                  .getExpenseById(savedExpense.id!);
        _removeExpense(occurrence.expense.id);
        if (previous != null) _appendExpenses([previous]);
        if (next != null) _appendExpenses([next]);
      } else {
        ref.read(expensesSessionProvider.notifier).updateLocal(savedExpense);
        _replaceExpense(occurrence.expense.id, savedExpense);
      }
      _publishOccurrences();
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to save category expense', error, stackTrace);
      if (!ref.mounted) return false;
      state = state.copyWith(status: state.status.failure(error));
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }

  void _replaceExpense(String? id, Expense updated) {
    if (id == null) return;
    final index = _expenses.indexWhere((expense) => expense.id == id);
    if (index != -1) _expenses[index] = updated;
    _sortExpenses();
    _updateEditingOccurrence(updated);
  }

  void _removeExpense(String? id) {
    if (id != null) _expenses.removeWhere((expense) => expense.id == id);
  }

  void _updateEditingOccurrence(Expense updated) {
    final editing = state.editingOccurrence;
    if (editing?.expense.id != updated.id) return;
    state = state.copyWith(
      editingOccurrence: ExpenseOccurrence(
        expense: updated,
        date: editing!.date,
        isDebited: updated.isDebitedAt(editing.date),
      ),
    );
  }

  Future<bool> deleteEditingExpense() async {
    final occurrence = state.editingOccurrence;
    return occurrence == null ? false : deleteOccurrence(occurrence);
  }

  Future<bool> deleteOccurrence(ExpenseOccurrence occurrence) async {
    if (occurrence.recurrence.isRecurring) {
      return deleteSingleOccurrence(occurrence);
    }
    if (state.isSaving || occurrence.id.isEmpty) return false;
    state = state.copyWith(isSaving: true);
    try {
      final success = await _expensesService.deleteExpense(
        occurrence.id,
        _accountId,
      );
      if (!ref.mounted) return success;
      if (success) {
        ref
            .read(expensesSessionProvider.notifier)
            .removeLocal(occurrence.id, _accountId);
        _removeExpense(occurrence.id);
        if (state.editingOccurrence?.id == occurrence.id) {
          state = state.copyWith(editingOccurrence: null);
        }
        _publishOccurrences();
      }
      return success;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to delete category expense', error, stackTrace);
      if (!ref.mounted) return false;
      state = state.copyWith(status: state.status.failure(error));
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<bool> deleteSingleOccurrence(ExpenseOccurrence occurrence) =>
      _deleteRecurring(
        occurrence,
        () => _expensesService.deleteSingleOccurrence(
          expense: occurrence.expense,
          occurrenceDate: occurrence.date,
        ),
      );

  Future<bool> deleteFutureOccurrences(ExpenseOccurrence occurrence) =>
      _deleteRecurring(
        occurrence,
        () => _expensesService.deleteFutureOccurrences(
          expense: occurrence.expense,
          occurrenceDate: occurrence.date,
        ),
      );

  Future<bool> _deleteRecurring(
    ExpenseOccurrence occurrence,
    Future<bool> Function() action,
  ) async {
    if (state.isSaving || occurrence.id.isEmpty) return false;
    state = state.copyWith(isSaving: true);
    try {
      final success = await action();
      if (!ref.mounted) return success;
      if (success) {
        // deleteSingleOccurrence/deleteFutureOccurrences only return whether
        // the write succeeded, not the resulting Expense, so pull the fresh
        // state from the server before re-deriving the local view of it.
        await ref
            .read(expensesSessionProvider.notifier)
            .loadAccount(_accountId, forceRefresh: true);
        if (!ref.mounted) return success;
        _syncAfterRecurringDelete(occurrence);
      }
      return success;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to delete recurring category expense',
        error,
        stackTrace,
      );
      if (!ref.mounted) return false;
      state = state.copyWith(status: state.status.failure(error));
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }

  void _syncAfterRecurringDelete(ExpenseOccurrence occurrence) {
    final updated = ref
        .read(expensesSessionProvider.notifier)
        .getExpenseById(occurrence.id);
    if (updated == null) {
      _removeExpense(occurrence.id);
      if (state.editingOccurrence?.id == occurrence.id) {
        state = state.copyWith(editingOccurrence: null);
      }
      _publishOccurrences();
      return;
    }
    _replaceExpense(occurrence.id, updated);
    for (final expense
        in ref
                .read(expensesSessionProvider)
                .expensesByAccount[updated.accountId] ??
            const <Expense>[]) {
      if (expense.id == null ||
          _expenses.any((item) => item.id == expense.id)) {
        continue;
      }
      if (expense.categoryId != _categoryId ||
          expense.accountId != _accountId) {
        continue;
      }
      final endExclusive = expense.endDateExclusive;
      final overlaps =
          expense.debitDate.isBefore(_period.startOfNextMonth) &&
          (endExclusive == null || endExclusive.isAfter(_period.startOfMonth));
      if (overlaps) _expenses.add(expense);
    }
    _sortExpenses();
    _publishOccurrences();
  }

  Future<bool> toggleEditingOccurrenceDebited() async {
    final occurrence = state.editingOccurrence;
    return occurrence == null ? false : toggleDebited(occurrence);
  }

  Future<bool> toggleDebited(ExpenseOccurrence occurrence) async {
    if (state.isSaving) return false;
    state = state.copyWith(isSaving: true);
    try {
      final updated = await _expensesService.toggleOccurrenceDebited(
        occurrence.expense,
        occurrence.date,
      );
      if (!ref.mounted) return true;
      ref.read(expensesSessionProvider.notifier).updateLocal(updated);
      _replaceExpense(occurrence.expense.id, updated);
      _publishOccurrences();
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to toggle category expense debit state',
        error,
        stackTrace,
      );
      if (!ref.mounted) return false;
      state = state.copyWith(status: state.status.failure(error));
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }
}

class ExpenseFormData {
  const ExpenseFormData({
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.debitDate,
    required this.endDate,
    required this.recurrence,
  });

  final String name;
  final double amount;
  final String? categoryId;
  final DateTime debitDate;
  final DateTime? endDate;
  final RecurrenceType recurrence;
}
