import 'package:flutter/foundation.dart';
import 'package:budgly/src/models/budget/account_budget.dart';

class AccountBudgetsStore extends ChangeNotifier {
  static AccountBudgetsStore? _instance;
  static AccountBudgetsStore get instance => _instance ??= AccountBudgetsStore._();
  AccountBudgetsStore._();

  final Map<String, AccountBudget?> _budgets = {};
  final Set<String> _loadedKeys = {};

  bool hasLoaded(String key) => _loadedKeys.contains(key);
  AccountBudget? get(String key) => _budgets[key];

  void set(String key, AccountBudget? budget) {
    _budgets[key] = budget;
    _loadedKeys.add(key);
    notifyListeners();
  }

  void clear(String key) {
    _loadedKeys.remove(key);
    _budgets.remove(key);
    notifyListeners();
  }

  void clearAll() {
    _loadedKeys.clear();
    _budgets.clear();
    notifyListeners();
  }

  void clearByAccountId(String accountId) {
    final prefix = '${accountId}_';
    final keysToRemove = _loadedKeys.where((k) => k.startsWith(prefix)).toList();
    if (keysToRemove.isEmpty) return;
    for (final key in keysToRemove) {
      _loadedKeys.remove(key);
      _budgets.remove(key);
    }
    notifyListeners();
  }
}
