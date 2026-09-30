import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/state/account_budgets_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAccountBudgetsService extends AccountBudgetsService {
  _FakeAccountBudgetsService(this.values)
    : super(analytics: AnalyticsService());

  final Map<String, AccountBudget?> values;
  bool shouldFailLoad = false;
  int invalidateCacheCalls = 0;

  String _key(String accountId, int year, int month) =>
      '${accountId}_${year}_$month';
  void Function(AccountBudget?)? _lastOnRevalidated;

  @override
  Future<AccountBudget?> loadRevenue(
    String accountId,
    int year,
    int month, {
    bool forceRefresh = false,
    void Function(AccountBudget?)? onRevalidated,
  }) async {
    _lastOnRevalidated = onRevalidated;
    if (shouldFailLoad) throw Exception('boom');
    return values[_key(accountId, year, month)];
  }

  /// Invokes the `onRevalidated` callback the session passed on the most
  /// recent `loadRevenue` call, as `AccountBudgetsService` itself would once
  /// its background revalidation completes.
  void simulateBackgroundRevalidation(AccountBudget? serverBudget) {
    _lastOnRevalidated?.call(serverBudget);
  }

  @override
  Future<AccountBudget> setRevenue(
    String accountId,
    int year,
    int month,
    double revenue,
  ) async {
    final budget = AccountBudget(
      accountId: accountId,
      year: year,
      month: month,
      revenue: revenue,
    );
    values[_key(accountId, year, month)] = budget;
    return budget;
  }

  @override
  void invalidateCache() => invalidateCacheCalls++;
}

void main() {
  test(
    'loadRevenue populates the shared state for that account/period',
    () async {
      final service = _FakeAccountBudgetsService({
        'a1_2026_3': const AccountBudget(
          accountId: 'a1',
          year: 2026,
          month: 3,
          revenue: 2500,
        ),
      });
      final container = ProviderContainer(
        overrides: [accountBudgetsServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(accountBudgetsSessionProvider.notifier);
      expect(notifier.hasLoaded('a1', 2026, 3), isFalse);

      final budget = await notifier.loadRevenue('a1', 2026, 3);

      expect(budget?.revenue, 2500);
      expect(notifier.hasLoaded('a1', 2026, 3), isTrue);
      expect(notifier.getRevenue('a1', 2026, 3), 2500);
      // A different account/period must not be affected.
      expect(notifier.hasLoaded('a1', 2026, 4), isFalse);
    },
  );

  test('a failing loadRevenue leaves the previous state untouched', () async {
    final service = _FakeAccountBudgetsService({
      'a1_2026_3': const AccountBudget(
        accountId: 'a1',
        year: 2026,
        month: 3,
        revenue: 2500,
      ),
    });
    final container = ProviderContainer(
      overrides: [accountBudgetsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(accountBudgetsSessionProvider.notifier);
    await notifier.loadRevenue('a1', 2026, 3);
    expect(notifier.getRevenue('a1', 2026, 3), 2500);

    service.shouldFailLoad = true;
    await expectLater(notifier.loadRevenue('a1', 2026, 3), throwsException);

    expect(notifier.getRevenue('a1', 2026, 3), 2500);
  });

  test('RL-01 §3.2: a background revalidation reported by the service updates '
      'the shared state so listeners (Overview, ...) rebuild', () async {
    final service = _FakeAccountBudgetsService({
      'a1_2026_3': const AccountBudget(
        accountId: 'a1',
        year: 2026,
        month: 3,
        revenue: 2500,
      ),
    });
    final container = ProviderContainer(
      overrides: [accountBudgetsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(accountBudgetsSessionProvider.notifier);
    await notifier.loadRevenue('a1', 2026, 3);
    expect(notifier.getRevenue('a1', 2026, 3), 2500);

    service.simulateBackgroundRevalidation(
      const AccountBudget(accountId: 'a1', year: 2026, month: 3, revenue: 3000),
    );

    expect(
      notifier.getRevenue('a1', 2026, 3),
      3000,
      reason:
          'the session must reflect the server-confirmed data, not stay '
          'frozen on the first cached snapshot',
    );
  });

  test('setRevenue writes the new value into the shared state', () async {
    final service = _FakeAccountBudgetsService({});
    final container = ProviderContainer(
      overrides: [accountBudgetsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(accountBudgetsSessionProvider.notifier);
    await notifier.setRevenue('a1', 2026, 3, 1800);

    expect(notifier.getRevenue('a1', 2026, 3), 1800);
    expect(notifier.hasLoaded('a1', 2026, 3), isTrue);
  });

  test(
    'clearAccount only drops keys for that account and forwards to the service',
    () async {
      final service = _FakeAccountBudgetsService({
        'a1_2026_3': const AccountBudget(
          accountId: 'a1',
          year: 2026,
          month: 3,
          revenue: 2500,
        ),
        'a2_2026_3': const AccountBudget(
          accountId: 'a2',
          year: 2026,
          month: 3,
          revenue: 900,
        ),
      });
      final container = ProviderContainer(
        overrides: [accountBudgetsServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(accountBudgetsSessionProvider.notifier);
      await notifier.loadRevenue('a1', 2026, 3);
      await notifier.loadRevenue('a2', 2026, 3);

      notifier.clearAccount('a1');

      expect(notifier.hasLoaded('a1', 2026, 3), isFalse);
      expect(notifier.hasLoaded('a2', 2026, 3), isTrue);
      expect(service.invalidateCacheCalls, 1);
    },
  );

  test('clear resets everything and forwards to the service', () async {
    final service = _FakeAccountBudgetsService({
      'a1_2026_3': const AccountBudget(
        accountId: 'a1',
        year: 2026,
        month: 3,
        revenue: 2500,
      ),
    });
    final container = ProviderContainer(
      overrides: [accountBudgetsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(accountBudgetsSessionProvider.notifier);
    await notifier.loadRevenue('a1', 2026, 3);
    notifier.clear();

    expect(notifier.hasLoaded('a1', 2026, 3), isFalse);
    expect(service.invalidateCacheCalls, 1);
  });
}
