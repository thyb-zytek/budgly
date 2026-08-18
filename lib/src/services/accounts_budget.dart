import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:budgly/src/stores/accounts_budget.dart';
import 'package:flutter/material.dart';

class AccountBudgetsService {
  static AccountBudgetsService? _instance;
  static AccountBudgetsService get instance => _instance ??= AccountBudgetsService._();
  AccountBudgetsService._();

  final AccountBudgetFirestore _provider = AccountBudgetFirestore();
  final AccountBudgetsStore _store = AccountBudgetsStore.instance;
  final Map<String, Future<void>> _loadFutures = {};
  int _sessionGeneration = 0;

  void addListener(VoidCallback listener) => _store.addListener(listener);
  void removeListener(VoidCallback listener) => _store.removeListener(listener);

  String _key(String accountId, int year, int month) => '${accountId}_${year}_$month';

  double getRevenue(String accountId, int year, int month) {
    return _store.get(_key(accountId, year, month))?.revenue ?? 0;
  }

  bool hasLoaded(String accountId, int year, int month) =>
      _store.hasLoaded(_key(accountId, year, month));

  Future<void> loadRevenue(String accountId, int year, int month, {bool forceRefresh = false}) async {
    final key = _key(accountId, year, month);
    if (!forceRefresh && _store.hasLoaded(key)) return;
    final inFlight = _loadFutures[key];
    if (inFlight != null) return inFlight;

    final future = _loadRevenue(key, accountId, year, month);
    _loadFutures[key] = future;
    try {
      await future;
    } finally {
      if (identical(_loadFutures[key], future)) _loadFutures.remove(key);
    }
  }

  Future<void> _loadRevenue(String key, String accountId, int year, int month) async {
    final generation = _sessionGeneration;
    final budget = await _provider.get(accountId, year, month);
    if (generation != _sessionGeneration) return;
    _store.set(key, budget);
  }

  void invalidateCache() {
    _sessionGeneration++;
    _loadFutures.clear();
    _store.clearAll();
  }

  Future<void> setRevenue(String accountId, int year, int month, double revenue) async {
    final generation = _sessionGeneration;
    final updated = await _provider.setRevenue(accountId, year, month, revenue);
    if (generation == _sessionGeneration) {
      _store.set(_key(accountId, year, month), updated);
    }
  }
}