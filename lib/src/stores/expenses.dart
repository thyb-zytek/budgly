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

  List<Expense> getExpensesForAccount(String accountId) =>
      List.unmodifiable(_expensesByAccount[accountId] ?? const []);

  bool hasLoadedAccount(String accountId) => _loadedAccounts.contains(accountId);

  void _sortByDebitDateDesc(List<Expense> expenses) {
    expenses.sort((a, b) => b.debitDate.compareTo(a.debitDate));
  }

  void setExpensesForAccount(String accountId, List<Expense> expenses) {
    final sorted = List<Expense>.from(expenses);
    _sortByDebitDateDesc(sorted);
    _expensesByAccount[accountId] = sorted;
    _loadedAccounts.add(accountId);
    notifyListeners();
  }

  /// Merges freshly-loaded expenses into the account cache so projections and
  /// pending-mutation lookups see every locally-known expense, even when a
  /// single period (or category page) has been loaded.
  void upsertExpensesForAccount(String accountId, List<Expense> expenses) {
    if (expenses.isEmpty) return;
    final byId = <String, Expense>{};
    final unnamed = <Expense>[];
    for (final expense in _expensesByAccount[accountId] ?? const <Expense>[]) {
      final id = expense.id;
      if (id == null) {
        unnamed.add(expense);
      } else {
        byId[id] ??= expense;
      }
    }
    for (final expense in expenses) {
      final id = expense.id;
      if (id == null) {
        unnamed.add(expense);
      } else {
        byId[id] = expense;
      }
    }
    final merged = [...byId.values, ...unnamed];
    _sortByDebitDateDesc(merged);
    _expensesByAccount[accountId] = merged;
    _loadedAccounts.add(accountId);
    notifyListeners();
  }

  Expense? getExpenseById(String expenseId) {
    for (final list in _expensesByAccount.values) {
      for (final expense in list) {
        if (expense.id == expenseId) return expense;
      }
    }
    return null;
  }

  void addExpense(Expense expense) {
    final list = _expensesByAccount.putIfAbsent(expense.accountId, () => []);
    list.add(expense);
    _sortByDebitDateDesc(list);
    notifyListeners();
  }

  void replaceExpenseWithVersions({
    required Expense previous,
    required Expense next,
  }) {
    for (final list in _expensesByAccount.values) {
      list.removeWhere((expense) => expense.id == previous.id);
    }

    final list = _expensesByAccount.putIfAbsent(next.accountId, () => []);
    list.add(previous);
    list.add(next);
    _sortByDebitDateDesc(list);
    notifyListeners();
  }

  void updateExpense(Expense expense) {
    String? sourceAccountId;
    int? sourceIndex;

    for (final entry in _expensesByAccount.entries) {
      final index = entry.value.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        sourceAccountId = entry.key;
        sourceIndex = index;
        break;
      }
    }

    if (sourceAccountId == null || sourceIndex == null) return;

    final source = _expensesByAccount[sourceAccountId]!;
    source.removeAt(sourceIndex);
    if (source.isEmpty) _expensesByAccount.remove(sourceAccountId);

    final target = _expensesByAccount.putIfAbsent(expense.accountId, () => []);
    target.add(expense);
    _sortByDebitDateDesc(target);
    notifyListeners();
  }

  void removeExpense(String expenseId, String accountId) {
    final list = _expensesByAccount[accountId];
    if (list == null) return;
    final before = list.length;
    list.removeWhere((e) => e.id == expenseId);
    if (list.length != before) notifyListeners();
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

  void clearAccountCache(String accountId) {
    final removedExpenses = _expensesByAccount.remove(accountId) != null;
    final removedLoaded = _loadedAccounts.remove(accountId);
    if (removedExpenses || removedLoaded) notifyListeners();
  }

  void clearAll() {
    if (_expensesByAccount.isEmpty && _loadedAccounts.isEmpty) return;
    _expensesByAccount.clear();
    _loadedAccounts.clear();
    notifyListeners();
  }
}
