import 'package:budgly/src/core/loading/loading_notifier.dart';
import 'package:flutter/foundation.dart';
import 'package:budgly/src/models/expense/expense.dart';

class ExpensesStore extends ChangeNotifier with LoadingNotifier {
  static ExpensesStore? _instance;

  static ExpensesStore get instance {
    _instance ??= ExpensesStore._();
    return _instance!;
  }

  ExpensesStore._();

  final Map<String, List<Expense>> _expensesByAccount = {};
  final Set<String> _loadedAccounts = {};

  Map<String, List<Expense>> get expensesByAccount => _expensesByAccount;

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

  void clearCategoryCache(String categoryId) {
    bool changed = false;
    for (final list in _expensesByAccount.values) {
      final before = list.length;
      list.removeWhere((e) => e.categoryId == categoryId);
      if (list.length != before) changed = true;
    }
    if (changed) notifyListeners();
  }

  void clearAll() {
    _expensesByAccount.clear();
    _loadedAccounts.clear();
    notifyListeners();
  }
}
