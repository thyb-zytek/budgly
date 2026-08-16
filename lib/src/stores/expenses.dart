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

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setExpensesForAccount(String accountId, List<Expense> expenses) {
    _expensesByAccount[accountId] = expenses;
    _loadedAccounts.add(accountId);
    notifyListeners();
  }

  void addExpense(Expense expense) {
    _expensesByAccount.putIfAbsent(expense.accountId, () => []);
    _expensesByAccount[expense.accountId]!.insert(0, expense);
    notifyListeners();
  }

  void updateExpense(Expense expense) {
    final list = _expensesByAccount[expense.accountId];
    if (list == null) return;
    final index = list.indexWhere((e) => e.id == expense.id);
    if (index != -1) list[index] = expense;
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
  }
}