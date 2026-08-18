import 'dart:ui';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:budgly/src/stores/expenses.dart';

class ExpensesService {
  static ExpensesService? _instance;

  static ExpensesService get instance {
    _instance ??= ExpensesService._();
    return _instance!;
  }

  final ExpenseFirestore _expenseFirestore = ExpenseFirestore();
  final ExpensesStore _store = ExpensesStore.instance;

  final Map<String, DateTime> _lastFetch = {};
  final Map<String, Future<List<Expense>>> _loadFutures = {};
  int _sessionGeneration = 0;
  static const Duration _cacheValidity = AppConstants.cacheValidityShort;

  ExpensesService._();

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
    _sessionGeneration++;
    _lastFetch.clear();
    _store.clearAll();
  }

  void invalidateAccountCache(String accountId) {
    _sessionGeneration++;
    _lastFetch.remove(accountId);
    _store.clearAccountCache(accountId);
  }

  Future<List<Expense>> listExpensesByAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async {
    final hasValidCache = _store.hasLoadedAccount(accountId) &&
        _lastFetch.containsKey(accountId) &&
        DateTime.now().difference(_lastFetch[accountId]!) < _cacheValidity;

    if (hasValidCache && !forceRefresh) {
      return _store.getExpensesForAccount(accountId);
    }
    final inFlight = _loadFutures[accountId];
    if (inFlight != null) return inFlight;

    final future = _loadExpenses(accountId);
    _loadFutures[accountId] = future;
    try {
      return await future;
    } finally {
      if (identical(_loadFutures[accountId], future)) _loadFutures.remove(accountId);
    }
  }

  Future<List<Expense>> _loadExpenses(String accountId) async {
    final generation = _sessionGeneration;
    _store.beginLoading();
    try {
      final freshExpenses = await _expenseFirestore.listByAccountId(accountId);
      if (generation != _sessionGeneration) return freshExpenses;
      _store.setExpensesForAccount(accountId, freshExpenses);
      _lastFetch[accountId] = DateTime.now();
      return freshExpenses;
    } finally {
      _store.endLoading();
    }
  }

  Future<Expense> createExpense(Expense expense) async {
    final generation = _sessionGeneration;
    final created = await _expenseFirestore.create(expense);

    if (created != null) {
      if (generation == _sessionGeneration) _store.addExpense(created);
      return created;
    }
    throw Exception('Failed to create expense');
  }

  Future<Expense> updateExpense(Expense expense) async {
    final generation = _sessionGeneration;
    final success = await _expenseFirestore.update(expense);

    if (success) {
      if (generation == _sessionGeneration) _store.updateExpense(expense);
      return expense;
    }
    throw Exception('Failed to update expense');
  }

  Future<bool> deleteExpense(String expenseId, String accountId) async {
    final generation = _sessionGeneration;
    final success = await _expenseFirestore.delete(expenseId);
    if (success) {
      if (generation == _sessionGeneration) _store.removeExpense(expenseId, accountId);
      return true;
    }
    throw Exception('Failed to delete expense');
  }

  Expense? getExpenseById(String expenseId) => _store.getExpenseById(expenseId);

  /// Marks the occurrence of [expense] on [date] as debited.
  ///
  /// For one-off expenses this flips the expense flag; for recurring ones
  /// only the given occurrence (matched by its ISO date) is marked, so the
  /// other occurrences keep their own state.
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

  /// Reverts the "debited" state of the occurrence of [expense] on [date].
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

  /// Toggles the debited state of the occurrence of [expense] on [date].
  Future<Expense> toggleOccurrenceDebited(Expense expense, DateTime date) async {
    return expense.isDebitedAt(date)
        ? unmarkOccurrenceDebited(expense, date)
        : markOccurrenceDebited(expense, date);
  }
}