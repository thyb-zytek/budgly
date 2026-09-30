import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:budgly/src/core/async/in_flight_registry.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';

class AccountBudgetsService {
  final AccountBudgetFirestore _provider;
  final _inFlight = InFlightRegistry<String>();
  final AnalyticsService _analytics;

  AccountBudgetsService({
    AccountBudgetFirestore? provider,
    required this._analytics,
  }) : _provider = provider ?? AccountBudgetFirestore();

  String _key(String accountId, int year, int month) =>
      '${accountId}_${year}_$month';

  String _docId(String accountId, int year, int month) =>
      _key(accountId, year, month);

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
    try {
      final cached = await _provider.getMostRecentWithRevenue(
        accountId,
        before: before,
        source: Source.cache,
      );
      if (cached != null) {
        _mostRecentRevenueCache[cacheKey] = cached.revenue;
        return cached.revenue;
      }
    } catch (_) {}
    try {
      final budget = await _provider.getMostRecentWithRevenue(
        accountId,
        before: before,
        source: Source.server,
      );
      final value = budget?.revenue;
      _mostRecentRevenueCache[cacheKey] = value;
      return value;
    } catch (_) {
      _mostRecentRevenueCache[cacheKey] = null;
      return null;
    }
  }

  /// Cache-first load (RL-01 §3.2); see `AccountsService.loadAccounts` for
  /// the [onRevalidated] contract this mirrors.
  Future<AccountBudget?> loadRevenue(
    String accountId,
    int year,
    int month, {
    bool forceRefresh = false,
    void Function(AccountBudget?)? onRevalidated,
  }) async {
    final key = _key(accountId, year, month);
    final existing = _inFlight.peek<AccountBudget?>(key);
    if (existing != null) {
      return forceRefresh ? await existing : await existing;
    }

    if (!forceRefresh) {
      try {
        final cached = await _provider.get(
          accountId,
          year,
          month,
          source: Source.cache,
        );
        unawaited(
          _refreshRevenueInBackground(
            key,
            accountId,
            year,
            month,
            onRevalidated: onRevalidated,
          ),
        );
        return cached;
      } on FirebaseException catch (e) {
        if (e.code != 'failed-precondition' && e.code != 'unavailable') {
          rethrow;
        }
      }
    }

    return await _refreshRevenue(key, accountId, year, month);
  }

  Future<void> _refreshRevenueInBackground(
    String key,
    String accountId,
    int year,
    int month, {
    void Function(AccountBudget?)? onRevalidated,
  }) async {
    try {
      final result = await _refreshRevenue(key, accountId, year, month);
      onRevalidated?.call(result);
    } catch (e) {
      AppLogger.debug('Background revenue refresh unavailable: $e');
    }
  }

  Future<AccountBudget?> _refreshRevenue(
    String key,
    String accountId,
    int year,
    int month,
  ) {
    final existing = _inFlight.peek<AccountBudget?>(key);
    if (existing != null) return existing;

    final future = _fetchRevenue(key, accountId, year, month);
    _inFlight.register(key, future);
    return future.whenComplete(() => _inFlight.release(key, future));
  }

  Future<AccountBudget?> _fetchRevenue(
    String key,
    String accountId,
    int year,
    int month,
  ) async {
    try {
      return await _provider.get(accountId, year, month);
    } catch (e, stackTrace) {
      _analytics.track('revenue_load_failed', {'error': e.toString()});
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
    _mostRecentRevenueCache.clear();
  }

  Future<AccountBudget> setRevenue(
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

    _mostRecentRevenueCache.removeWhere(
      (key, _) => key.startsWith('$accountId|'),
    );
    _analytics.track('budget_updated');
    _analytics.track('revenue_set');

    // Firestore persists writes locally and synchronizes them when possible.
    // The UI only needs the optimistic/store state above.
    unawaited(_persistRevenue(key, accountId, year, month, revenue));
    return optimistic;
  }

  Future<void> _persistRevenue(
    String key,
    String accountId,
    int year,
    int month,
    double revenue,
  ) async {
    try {
      await _provider.setRevenue(accountId, year, month, revenue);
      _mostRecentRevenueCache.removeWhere(
        (key, _) => key.startsWith('$accountId|'),
      );
    } catch (e, stackTrace) {
      _analytics.track('revenue_set_failed', {'error': e.toString()});
      AppLogger.error('Failed to persist revenue', e, stackTrace);
    }
  }

  /// Immediate, local best-effort removal that never waits for the server (see
  /// `ExpensesService.deleteByAccountId`).
  Future<void> deleteByAccountId(String accountId) async {
    try {
      await _provider.deleteByAccountId(accountId, awaitAck: false);
    } catch (e) {
      AppLogger.debug('Local budget removal unavailable: $e');
    }
    _inFlight.clear();
    _mostRecentRevenueCache.removeWhere(
      (key, _) => key.startsWith('$accountId|'),
    );
  }

  /// Server-side removal used by the durable cleanup; throws when the server
  /// cannot be reached so the caller retries.
  Future<void> purgeByAccountId(String accountId) =>
      _provider.deleteByAccountId(accountId, source: Source.server);
}
