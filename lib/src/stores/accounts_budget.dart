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
  }
}