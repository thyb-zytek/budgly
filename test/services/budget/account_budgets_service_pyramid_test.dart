import 'dart:async';

import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:budgly/src/stores/accounts_budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _BudgetProvider extends AccountBudgetFirestore {
  final Map<String, AccountBudget?> cache = {};
  final Map<String, AccountBudget?> server = {};
  final Completer<void>? serverGate;
  int getCalls = 0;
  int setCalls = 0;

  _BudgetProvider({this.serverGate});

  String key(String accountId, int year, int month) =>
      '${accountId}_${year}_$month';

  @override
  Future<AccountBudget?> get(
    String accountId,
    int year,
    int month, {
    Source source = Source.server,
  }) async {
    getCalls++;
    if (source == Source.cache) {
      final value = cache[key(accountId, year, month)];
      return value;
    }
    if (serverGate != null) await serverGate!.future;
    return server[key(accountId, year, month)];
  }

  @override
  Future<AccountBudget> setRevenue(
    String accountId,
    int year,
    int month,
    double revenue,
  ) async {
    setCalls++;
    final budget = AccountBudget(
      id: key(accountId, year, month),
      accountId: accountId,
      year: year,
      month: month,
      revenue: revenue,
    );
    server[key(accountId, year, month)] = budget;
    return budget;
  }

  @override
  Future<AccountBudget?> getMostRecentWithRevenue(
    String accountId, {
    required Period before,
    Source source = Source.server,
  }) async {
    return null;
  }
}

AccountBudget budget(String accountId, int year, int month, double revenue) =>
    AccountBudget(
      accountId: accountId,
      year: year,
      month: month,
      revenue: revenue,
    );

void main() {
  late AccountBudgetsStore store;

  setUp(() {
    store = AccountBudgetsStore.instance;
    store.clearAll();
  });

  tearDown(() => store.clearAll());

  test('loadRevenue uses cached data without blocking on the first read', () async {
    final provider = _BudgetProvider();
    provider.cache['a1_2026_8'] = budget('a1', 2026, 8, 2500);
    final service = AccountBudgetsService(provider: provider, store: store);

    await service.loadRevenue('a1', 2026, 8);

    expect(service.getRevenue('a1', 2026, 8), 2500);
    expect(service.hasLoaded('a1', 2026, 8), isTrue);
  });

  test('loadRevenue falls back to server when the cache is unavailable', () async {
    final provider = _BudgetProvider();
    provider.server['a1_2026_8'] = budget('a1', 2026, 8, 3100);
    // FirebaseException is intentionally used here because it is the exact
    // failure class the production code treats as a recoverable cache miss.
    final service = AccountBudgetsService(
      provider: _CacheMissProvider(provider),
      store: store,
    );

    await service.loadRevenue('a1', 2026, 8);

    expect(service.getRevenue('a1', 2026, 8), 3100);
  });

  test('force refresh reads the server even when local state is already loaded', () async {
    final provider = _BudgetProvider();
    provider.server['a1_2026_8'] = budget('a1', 2026, 8, 900);
    final service = AccountBudgetsService(provider: provider, store: store);

    store.set('a1_2026_8', budget('a1', 2026, 8, 100));
    await service.loadRevenue('a1', 2026, 8, forceRefresh: true);

    expect(service.getRevenue('a1', 2026, 8), 900);
    expect(provider.getCalls, 1);
  });

  test('concurrent force refreshes share the in-flight request', () async {
    final gate = Completer<void>();
    final provider = _BudgetProvider(serverGate: gate);
    provider.server['a1_2026_8'] = budget('a1', 2026, 8, 1200);
    final service = AccountBudgetsService(provider: provider, store: store);

    final first = service.loadRevenue('a1', 2026, 8, forceRefresh: true);
    final second = service.loadRevenue('a1', 2026, 8, forceRefresh: true);

    await Future<void>.delayed(Duration.zero);
    expect(provider.getCalls, 1);

    gate.complete();
    await Future.wait([first, second]);

    expect(service.getRevenue('a1', 2026, 8), 1200);
  });

  test('setRevenue updates the store optimistically and persists asynchronously',
      () async {
    final provider = _BudgetProvider();
    final service = AccountBudgetsService(provider: provider, store: store);

    await service.setRevenue('a1', 2026, 8, 1750);

    expect(service.getRevenue('a1', 2026, 8), 1750);
    await Future<void>.delayed(Duration.zero);
    expect(provider.setCalls, 1);
  });
}

class _CacheMissProvider extends AccountBudgetFirestore {
  final _BudgetProvider delegate;

  _CacheMissProvider(this.delegate);

  @override
  Future<AccountBudget?> get(
    String accountId,
    int year,
    int month, {
    Source source = Source.server,
  }) {
    if (source == Source.cache) {
      throw FirebaseException(plugin: 'test', code: 'unavailable');
    }
    return delegate.get(accountId, year, month, source: source);
  }
}
