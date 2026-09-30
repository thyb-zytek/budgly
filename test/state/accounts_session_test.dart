import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';

class _FakeAccountsService extends AccountsService {
  _FakeAccountsService(this.values)
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );

  final List<Account> values;
  bool shouldFailLoad = false;
  int loadCalls = 0;
  bool clearLocalAccountsCalled = false;
  void Function(List<Account>)? _lastOnRevalidated;

  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async {
    loadCalls++;
    _lastOnRevalidated = onRevalidated;
    if (shouldFailLoad) throw Exception('boom');
    return List.of(values);
  }

  /// Invokes the `onRevalidated` callback the session passed on the most
  /// recent `loadAccounts` call, as `AccountsService` itself would once its
  /// background revalidation completes.
  void simulateBackgroundRevalidation(List<Account> serverAccounts) {
    _lastOnRevalidated?.call(serverAccounts);
  }

  @override
  void clearLocalAccounts() {
    clearLocalAccountsCalled = true;
    super.clearLocalAccounts();
  }

  @override
  Future<Account> createAccount(Account account) async {
    values.add(account);
    return account;
  }

  @override
  Future<Account> updateAccount(Account account) async {
    final index = values.indexWhere((a) => a.id == account.id);
    if (index != -1) values[index] = account;
    return account;
  }

  @override
  Future<bool> deleteAccount(String accountId) async {
    values.removeWhere((a) => a.id == accountId);
    return true;
  }
}

void main() {
  test('load populates the shared state', () async {
    final service = _FakeAccountsService([
      Fixtures.account(id: 'a2', name: 'Zébulon'),
      Fixtures.account(id: 'a1', name: 'Alpha'),
    ]);
    final container = ProviderContainer(
      overrides: [accountsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    expect(container.read(accountsSessionProvider).hasLoaded, isFalse);

    await container.read(accountsSessionProvider.notifier).load();

    final state = container.read(accountsSessionProvider);
    expect(state.hasLoaded, isTrue);
    // Regression: load() used to keep whatever order the service returned,
    // while updateLocal()/setAccounts() sorted by name. An account list that
    // reordered itself right after the first background revalidation was the
    // visible symptom.
    expect(state.accounts.map((a) => a.id), ['a1', 'a2']);
    expect(service.loadCalls, 1);
  });

  test('a failing load leaves the previous state untouched', () async {
    final service = _FakeAccountsService([
      Fixtures.account(id: 'a1', name: 'Alpha'),
    ]);
    final container = ProviderContainer(
      overrides: [accountsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await container.read(accountsSessionProvider.notifier).load();
    expect(container.read(accountsSessionProvider).accounts, hasLength(1));

    service.shouldFailLoad = true;
    await expectLater(
      container.read(accountsSessionProvider.notifier).load(),
      throwsException,
    );

    // The previously loaded account is still there: a failed refresh must
    // not wipe out data the user already saw.
    expect(container.read(accountsSessionProvider).accounts, hasLength(1));
  });

  test('create adds the new account to the shared state', () async {
    final service = _FakeAccountsService([]);
    final container = ProviderContainer(
      overrides: [accountsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final created = await container
        .read(accountsSessionProvider.notifier)
        .create(Fixtures.account(id: 'a1', name: 'Alpha'));

    expect(created.id, 'a1');
    expect(container.read(accountsSessionProvider).accounts.map((a) => a.id), [
      'a1',
    ]);
  });

  test('update replaces the matching account in the shared state', () async {
    final service = _FakeAccountsService([
      Fixtures.account(id: 'a1', name: 'Alpha'),
    ]);
    final container = ProviderContainer(
      overrides: [accountsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await container.read(accountsSessionProvider.notifier).load();
    final updated = await container
        .read(accountsSessionProvider.notifier)
        .update(Fixtures.account(id: 'a1', name: 'Alpha renommé'));

    expect(updated.name, 'Alpha renommé');
    expect(
      container.read(accountsSessionProvider).accounts.single.name,
      'Alpha renommé',
    );
  });

  test('delete removes the account from the shared state', () async {
    final service = _FakeAccountsService([
      Fixtures.account(id: 'a1', name: 'Alpha'),
    ]);
    final container = ProviderContainer(
      overrides: [accountsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await container.read(accountsSessionProvider.notifier).load();
    final deleted = await container
        .read(accountsSessionProvider.notifier)
        .delete('a1');

    expect(deleted, isTrue);
    expect(container.read(accountsSessionProvider).accounts, isEmpty);
  });

  test('create keeps accounts sorted by name', () async {
    final service = _FakeAccountsService([]);
    final container = ProviderContainer(
      overrides: [accountsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await container
        .read(accountsSessionProvider.notifier)
        .create(Fixtures.account(id: 'a2', name: 'Zébulon'));
    await container
        .read(accountsSessionProvider.notifier)
        .create(Fixtures.account(id: 'a1', name: 'Alpha'));

    expect(container.read(accountsSessionProvider).accounts.map((a) => a.id), [
      'a1',
      'a2',
    ]);
  });

  test('RL-01 §3.2: a background revalidation reported by the service updates '
      'the shared state so listeners (Overview, ...) rebuild', () async {
    final service = _FakeAccountsService([
      Fixtures.account(id: 'a1', name: 'Alpha'),
    ]);
    final container = ProviderContainer(
      overrides: [accountsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await container.read(accountsSessionProvider.notifier).load();
    expect(container.read(accountsSessionProvider).accounts.map((a) => a.id), [
      'a1',
    ]);

    // Simulate the service completing a background revalidation *after*
    // `load()` already returned the cache-first snapshot above — exactly
    // what `AccountsService.loadAccounts`'s cache-hit branch does.
    service.simulateBackgroundRevalidation([
      Fixtures.account(id: 'a1', name: 'Alpha'),
      Fixtures.account(id: 'a2', name: 'Bravo'),
    ]);

    expect(
      container.read(accountsSessionProvider).accounts.map((a) => a.id),
      ['a1', 'a2'],
      reason:
          'the session must reflect the server-confirmed data, not stay '
          'frozen on the first cached snapshot',
    );
  });

  test('clear resets the state as if nothing had ever loaded', () async {
    final service = _FakeAccountsService([
      Fixtures.account(id: 'a1', name: 'Alpha'),
    ]);
    final container = ProviderContainer(
      overrides: [accountsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await container.read(accountsSessionProvider.notifier).load();
    container.read(accountsSessionProvider.notifier).clear();

    final state = container.read(accountsSessionProvider);
    expect(state.hasLoaded, isFalse);
    expect(state.accounts, isEmpty);
    // Regression (docs/AUDIT_PLAN.md, X3): clear() must also invalidate the
    // service's own cache, like CategoriesSession/ExpensesSession/
    // AccountBudgetsSession.clear() already do — otherwise a stale account
    // list could survive a sign-out and leak into the next signed-in user.
    expect(service.clearLocalAccountsCalled, isTrue);
  });
}
