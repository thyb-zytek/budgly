import 'dart:ui';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/services/cache/cache_controller.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:budgly/src/stores/expenses.dart';

class ExpensesService {
  static ExpensesService? _instance;

  static ExpensesService get instance {
    _instance ??= ExpensesService._();
    return _instance!;
  }

  final ExpenseFirestore _expenseFirestore;
  final ExpensesStore _store;

  final CacheController<String> _cache =
      CacheController<String>(ttl: AppConstants.cacheValidityShort);

  ExpensesService({
    ExpenseFirestore? expenseFirestore,
    ExpensesStore? store,
  })  : _expenseFirestore = expenseFirestore ?? ExpenseFirestore(),
        _store = store ?? ExpensesStore.instance;

  ExpensesService._() : this();

  bool get isLoading => _store.isLoading;
  bool hasLoadedAccount(String accountId) => _store.hasLoadedAccount(accountId);
  List<Expense> getExpensesForAccount(String accountId) =>
      _store.getExpensesForAccount(accountId);

  void addListener(VoidCallback listener) {
    _store.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    _store.removeListener(listener);
  }

  void invalidateCache() {
    _cache.invalidate();
    _store.clearAll();
  }

  void invalidateAccountCache(String accountId) {
    _cache.invalidate(accountId);
    _store.clearAccountCache(accountId);
  }

  Future<List<Expense>> listExpensesByAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _store.hasLoadedAccount(accountId) &&
        _cache.isFresh(accountId)) {
      return _store.getExpensesForAccount(accountId);
    }

    final inFlight = _cache.inFlight(accountId);
    if (inFlight != null) {
      await inFlight;
      return _store.getExpensesForAccount(accountId);
    }

    final future = _loadExpenses(accountId);
    _cache.track(accountId, future);
    try {
      await future;
      return _store.getExpensesForAccount(accountId);
    } finally {
      _cache.untrack(accountId, future);
    }
  }

  Future<List<Expense>> _loadExpenses(String accountId) async {
    final generation = _cache.generation;
    _store.beginLoading();
    try {
      final freshExpenses = await _expenseFirestore.listByAccountId(accountId);
      if (generation != _cache.generation) return freshExpenses;
      _store.setExpensesForAccount(accountId, freshExpenses);
      _cache.markFresh(accountId);
      return freshExpenses;
    } finally {
      _store.endLoading();
    }
  }

  Future<Expense> createExpense(Expense expense) async {
    final generation = _cache.generation;
    final created = await _expenseFirestore.create(expense);

    if (created != null) {
      if (generation == _cache.generation) _store.addExpense(created);
      return created;
    }
    throw Exception('Failed to create expense');
  }

  Future<Expense> updateExpense(Expense expense) async {
    final generation = _cache.generation;
    final success = await _expenseFirestore.update(expense);

    if (success) {
      if (generation == _cache.generation) _store.updateExpense(expense);
      return expense;
    }
    throw Exception('Failed to update expense');
  }

  Future<bool> deleteExpense(String expenseId, String accountId) async {
    final generation = _cache.generation;
    final success = await _expenseFirestore.delete(expenseId);
    if (success) {
      if (generation == _cache.generation) _store.removeExpense(expenseId, accountId);
      return true;
    }
    throw Exception('Failed to delete expense');
  }

  Expense? getExpenseById(String expenseId) => _store.getExpenseById(expenseId);

  Future<void> deleteByAccountId(String accountId) async {
    await _expenseFirestore.deleteByAccountId(accountId);
    _store.clearAccountCache(accountId);
  }

  Future<void> deleteByCategoryId(String categoryId) async {
    await _expenseFirestore.deleteByCategoryId(categoryId);
    _store.clearCategoryCache(categoryId);
  }

  Future<Expense> markOccurrenceDebited(Expense expense, DateTime date) async {
    if (expense.isRecurring) {
      final key = Expense.isoDate(date);
      if (expense.debitedOccurrences.contains(key)) return expense;
      return updateExpense(
        expense.copyWith(
          debitedOccurrences: [...expense.debitedOccurrences, key],
        ),
      );
    }
    if (expense.isDebited) return expense;
    return updateExpense(expense.copyWith(isDebited: true));
  }

  Future<Expense> unmarkOccurrenceDebited(
    Expense expense,
    DateTime date,
  ) async {
    if (expense.isRecurring) {
      final key = Expense.isoDate(date);
      if (!expense.debitedOccurrences.contains(key)) return expense;
      return updateExpense(
        expense.copyWith(
          debitedOccurrences: expense.debitedOccurrences
              .where((k) => k != key)
              .toList(),
        ),
      );
    }
    if (!expense.isDebited) return expense;
    return updateExpense(expense.copyWith(isDebited: false));
  }

  Future<Expense> toggleOccurrenceDebited(Expense expense, DateTime date) async {
    return expense.isDebitedAt(date)
        ? unmarkOccurrenceDebited(expense, date)
        : markOccurrenceDebited(expense, date);
  }
}
