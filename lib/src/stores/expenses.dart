import 'package:flutter/foundation.dart';
import 'package:budgly/src/models/expense/expense.dart';

class ExpensesStore extends ChangeNotifier {
  static ExpensesStore? _instance;

  static ExpensesStore get instance {
    _instance ??= ExpensesStore._();
    return _instance!;
  }

  ExpensesStore._();

  final Map<String, List<Expense>> _expensesByAccount = {};
  final Set<String> _loadedAccounts = {};
  bool _isLoading = false;
  int _loadingCount = 0;

  Map<String, List<Expense>> get expensesByAccount => _expensesByAccount;
  bool get isLoading => _isLoading;

  bool hasLoadedAccount(String accountId) => _loadedAccounts.contains(accountId);

  List<Expense> getExpensesForAccount(String accountId) {
    return List.unmodifiable(_expensesByAccount[accountId] ?? const []);
  }

  Expense? getExpenseById(String expenseId) {
    for (final list in _expensesByAccount.values) {
      for (final expense in list) {
        if (expense.id == expenseId) return expense;
      }
    }
    return null;
  }

  void beginLoading() {
    _loadingCount++;
    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();
    }
  }

  void endLoading() {
    if (_loadingCount > 0) _loadingCount--;
    if (_loadingCount == 0 && _isLoading) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setLoading(bool value) {
    if (value) {
      beginLoading();
    } else {
      _loadingCount = 0;
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void setExpensesForAccount(String accountId, List<Expense> expenses) {
    final sorted = List<Expense>.from(expenses)
      ..sort((a, b) => b.debitDate.compareTo(a.debitDate));
    _expensesByAccount[accountId] = sorted;
    _loadedAccounts.add(accountId);
    notifyListeners();
  }

  void addExpense(Expense expense) {
    final list = _expensesByAccount.putIfAbsent(expense.accountId, () => []);
    list.add(expense);
    list.sort((a, b) => b.debitDate.compareTo(a.debitDate));
    notifyListeners();
  }

  void updateExpense(Expense expense) {
    // Remove the previous copy first so this also works if accountId changes.
    for (final list in _expensesByAccount.values) {
      list.removeWhere((e) => e.id == expense.id);
    }

    final list = _expensesByAccount.putIfAbsent(expense.accountId, () => []);
    list.add(expense);
    list.sort((a, b) => b.debitDate.compareTo(a.debitDate));
    notifyListeners();
  }

  void removeExpense(String expenseId, String accountId) {
    _expensesByAccount[accountId]?.removeWhere((e) => e.id == expenseId);
    notifyListeners();
  }

  void clearAccountCache(String accountId) {
    _expensesByAccount.remove(accountId);
    _loadedAccounts.remove(accountId);
    notifyListeners();
  }

  void clearAll() {
    _expensesByAccount.clear();
    _loadedAccounts.clear();
    notifyListeners();
  }
}