import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:budgly/src/core/async/in_flight_registry.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:budgly/src/stores/accounts_budget.dart';

class AccountBudgetsService {
  static AccountBudgetsService? _instance;

  static AccountBudgetsService get instance {
    _instance ??= AccountBudgetsService._();
    return _instance!;
  }

  final AccountBudgetFirestore _provider;
  final AccountBudgetsStore _store;
  final _inFlight = InFlightRegistry<String>();

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

  String _docId(String accountId, int year, int month) => _key(accountId, year, month);

  double getRevenue(String accountId, int year, int month) {
    return _store.get(_key(accountId, year, month))?.revenue ?? 0;
  }

  final Map<String, double?> _mostRecentRevenueCache = {};

  /// Returns the most recent revenue strictly earlier than [before] for the
  /// given account. A period never inherits revenue from its own or a future
  /// month, so the result is cached per (account, period).
  Future<double?> getMostRecentRevenue(
    String accountId, {
    required Period before,
  }) async {
    final cacheKey = '$accountId|${before.year}_${before.month}';
    if (_mostRecentRevenueCache.containsKey(cacheKey)) {
      return _mostRecentRevenueCache[cacheKey];
    }

    // Offline-first: try the local store first so a period change while
    // offline can still inherit revenue from a previously loaded month.
    final storeBudgets = _store.getBudgetsForAccount(accountId);
    final fromStore = firstRevenueBefore(storeBudgets, before);
    if (fromStore != null) {
      _mostRecentRevenueCache[cacheKey] = fromStore.revenue;
      return fromStore.revenue;
    }

    // Try Firestore cache query before hitting the network.
    try {
      final cached =
          await _provider.getMostRecentWithRevenue(accountId, before: before, source: Source.cache);
      if (cached != null) {
        _mostRecentRevenueCache[cacheKey] = cached.revenue;
        return cached.revenue;
      }
    } catch (_) {
      // Cache query unavailable (e.g. missing index) — fall through to per-doc fallback.
    }

    // Fallback: walk backwards month-by-month using direct doc gets
    // (Source.cache). This is more reliable offline than a range query
    // and can find Nov 2026 for Feb 2027 even when the 60-doc query
    // is not cached.
    for (int offset = 1; offset <= 60; offset++) {
      final candidate = before.addMonths(-offset);
      final key = _key(accountId, candidate.year, candidate.month);
      if (_store.hasLoaded(key)) {
        final budget = _store.get(key);
        if (budget != null && budget.revenue > 0) {
          _mostRecentRevenueCache[cacheKey] = budget.revenue;
          return budget.revenue;
        }
        continue;
      }
      try {
        final budget = await _provider.get(
          accountId,
          candidate.year,
          candidate.month,
          source: Source.cache,
        );
        if (budget != null) {
          _store.set(key, budget);
          if (budget.revenue > 0) {
            _mostRecentRevenueCache[cacheKey] = budget.revenue;
            return budget.revenue;
          }
        } else {
          _store.set(key, null);
        }
      } catch (_) {
        continue;
      }
    }

    try {
      final budget =
          await _provider.getMostRecentWithRevenue(accountId, before: before, source: Source.server);
      final value = budget?.revenue;
      _mostRecentRevenueCache[cacheKey] = value;
      return value;
    } catch (_) {
      _mostRecentRevenueCache[cacheKey] = null;
      return null;
    }
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
    final existing = _inFlight.peek<void>(key);
    if (existing != null) {
      if (forceRefresh) await existing;
      return;
    }

    if (!forceRefresh) {
      try {
        final cached = await _provider.get(
          accountId,
          year,
          month,
          source: Source.cache,
        );
        _store.set(key, cached);
        unawaited(_refreshRevenueInBackground(key, accountId, year, month));
        return;
      } on FirebaseException catch (e) {
        if (e.code != 'failed-precondition' && e.code != 'unavailable') {
          rethrow;
        }
      }
    }

    await _refreshRevenue(key, accountId, year, month);
  }

  Future<void> _refreshRevenueInBackground(
    String key,
    String accountId,
    int year,
    int month,
  ) async {
    try {
      await _refreshRevenue(key, accountId, year, month);
    } catch (e) {
      AppLogger.debug('Background revenue refresh unavailable: $e');
    }
  }

  Future<void> _refreshRevenue(
    String key,
    String accountId,
    int year,
    int month,
  ) {
    final existing = _inFlight.peek<void>(key);
    if (existing != null) return existing;

    final future = _fetchAndStoreRevenue(key, accountId, year, month);
    _inFlight.register(key, future);
    return future.whenComplete(() => _inFlight.release(key, future));
  }

  Future<void> _fetchAndStoreRevenue(
    String key,
    String accountId,
    int year,
    int month,
  ) async {
    try {
      final budget = await _provider.get(accountId, year, month);
      _store.set(key, budget);
    } catch (e, stackTrace) {
      AnalyticsService.instance.track('revenue_load_failed', {'error': e.toString()});
      AppLogger.error('Failed to load revenue', e, stackTrace);
      rethrow;
    }
  }

  /// Clears only the derived inherited-revenue lookup cache without removing
  /// already loaded monthly budgets.
  void invalidateMostRecentRevenueCache() {
    _mostRecentRevenueCache.clear();
  }

  void invalidateCache() {
    _inFlight.clear();
    _store.clearAll();
    _mostRecentRevenueCache.clear();
  }

  Future<void> setRevenue(
    String accountId,
    int year,
    int month,
    double revenue,
  ) async {
    final key = _key(accountId, year, month);
    final optimistic = AccountBudget(
      id: _docId(accountId, year, month),
      accountId: accountId,
      year: year,
      month: month,
      revenue: revenue,
    );

    _store.set(key, optimistic);
    _mostRecentRevenueCache
        .removeWhere((key, _) => key.startsWith('$accountId|'));
    AnalyticsService.instance.track('budget_updated');
    AnalyticsService.instance.track('revenue_set');

    // Firestore persists writes locally and synchronizes them when possible.
    // The UI only needs the optimistic/store state above.
    unawaited(_persistRevenue(key, accountId, year, month, revenue));
  }

  Future<void> _persistRevenue(
    String key,
    String accountId,
    int year,
    int month,
    double revenue,
  ) async {
    try {
      final updated = await _provider.setRevenue(
        accountId,
        year,
        month,
        revenue,
      );
      _store.set(key, updated);
    } catch (e, stackTrace) {
      AnalyticsService.instance.track(
        'revenue_set_failed',
        {'error': e.toString()},
      );
      AppLogger.error('Failed to persist revenue', e, stackTrace);
    }
  }

  Future<void> deleteByAccountId(String accountId) async {
    await _provider.deleteByAccountId(accountId);
    _store.clearByAccountId(accountId);
    _inFlight.clear();
    _mostRecentRevenueCache
        .removeWhere((key, _) => key.startsWith('$accountId|'));
  }
}
