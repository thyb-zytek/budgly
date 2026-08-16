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
    _lastFetch.clear();
    _store.clearAll();
  }

  void invalidateAccountCache(String accountId) {
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

    _store.setLoading(true);

    try {
      final freshExpenses = await _expenseFirestore.listByAccountId(accountId);
      _store.setExpensesForAccount(accountId, freshExpenses);
      _lastFetch[accountId] = DateTime.now();
      return freshExpenses;
    } finally {
      _store.setLoading(false);
    }
  }

  Future<Expense> createExpense(Expense expense) async {
    final created = await _expenseFirestore.create(expense);

    if (created != null) {
      _store.addExpense(created);
      return created;
    }
    throw Exception('Failed to create expense');
  }

  Future<Expense> updateExpense(Expense expense) async {
    final success = await _expenseFirestore.update(expense);

    if (success) {
      _store.updateExpense(expense);
      return expense;
    }
    throw Exception('Failed to update expense');
  }

  Future<bool> deleteExpense(String expenseId, String accountId) async {
    final success = await _expenseFirestore.delete(expenseId);
    if (success) {
      _store.removeExpense(expenseId, accountId);
      return true;
    }
    throw Exception('Failed to delete expense');
  }

  Expense? getExpenseById(String expenseId) => _store.getExpenseById(expenseId);
}