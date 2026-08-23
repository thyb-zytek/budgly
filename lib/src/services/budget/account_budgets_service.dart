import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/services/cache/cache_controller.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:budgly/src/stores/accounts_budget.dart';
import 'package:flutter/material.dart';

class AccountBudgetsService {
  static AccountBudgetsService? _instance;

  static AccountBudgetsService get instance {
    _instance ??= AccountBudgetsService._();
    return _instance!;
  }

  final AccountBudgetFirestore _provider;
  final AccountBudgetsStore _store;
  final CacheController<String> _cache = CacheController<String>(
    ttl: AppConstants.cacheValidityShort,
  );

  AccountBudgetsService({
    AccountBudgetFirestore? provider,
    AccountBudgetsStore? store,
  })  : _provider = provider ?? AccountBudgetFirestore(),
        _store = store ?? AccountBudgetsStore.instance;

  AccountBudgetsService._() : this();

  void addListener(VoidCallback listener) => _store.addListener(listener);
  void removeListener(VoidCallback listener) => _store.removeListener(listener);

  String _key(String accountId, int year, int month) =>
      '${accountId}_${year}_$month';

  double getRevenue(String accountId, int year, int month) {
    return _store.get(_key(accountId, year, month))?.revenue ?? 0;
  }

  final Map<String, double?> _mostRecentRevenueCache = {};

  Future<double?> getMostRecentRevenue(String accountId) async {
    if (_mostRecentRevenueCache.containsKey(accountId)) {
      return _mostRecentRevenueCache[accountId];
    }
    final budget = await _provider.getMostRecentWithRevenue(accountId);
    final value = budget?.revenue;
    _mostRecentRevenueCache[accountId] = value;
    return value;
  }

  bool hasLoaded(String accountId, int year, int month) =>
      _store.hasLoaded(_key(accountId, year, month));

  Future<void> loadRevenue(
    String accountId,
    int year,
    int month, {
    bool forceRefresh = false,
  }) async {
    final key = _key(accountId, year, month);
    if (!forceRefresh && _store.hasLoaded(key) && _cache.isFresh(key)) {
      return;
    }

    final inFlight = _cache.inFlight(key);
    if (inFlight != null) return inFlight;

    final future = _loadRevenue(key, accountId, year, month);
    _cache.track(key, future);
    try {
      await future;
    } finally {
      _cache.untrack(key, future);
    }
  }

  Future<void> _loadRevenue(
    String key,
    String accountId,
    int year,
    int month,
  ) async {
    final generation = _cache.generation;
    final budget = await _provider.get(accountId, year, month);
    if (generation != _cache.generation) return;
    _store.set(key, budget);
    _cache.markFresh(key);
  }

  void invalidateCache() {
    _cache.invalidate();
    _store.clearAll();
    _mostRecentRevenueCache.clear();
  }

  Future<void> setRevenue(
    String accountId,
    int year,
    int month,
    double revenue,
  ) async {
    final generation = _cache.generation;
    final key = _key(accountId, year, month);
    final updated = await _provider.setRevenue(accountId, year, month, revenue);
    if (generation == _cache.generation) {
      _store.set(key, updated);
      _cache.markFresh(key);
    }
    _mostRecentRevenueCache.remove(accountId);
  }

  Future<void> deleteByAccountId(String accountId) async {
    await _provider.deleteByAccountId(accountId);
    _store.clearByAccountId(accountId);
    _cache.invalidate();
    _mostRecentRevenueCache.remove(accountId);
  }
}
