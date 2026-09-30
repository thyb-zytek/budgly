import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/pages/overview/revenue_provider.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/state/account_budgets_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(analytics: AnalyticsService());
  @override
  User? get currentUser => null;

  @override
  fb.User? get firebaseUser => null;
}

class _FakeProfileService extends ProfileService {
  _FakeProfileService()
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );
  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async => null;

  @override
  Future<User?> refreshFromServer() async => null;
}

class _FakeAccountBudgetsService extends AccountBudgetsService {
  _FakeAccountBudgetsService(this.values, {this.mostRecentRevenue})
    : super(analytics: AnalyticsService());

  final Map<String, AccountBudget?> values;
  double? mostRecentRevenue;
  int invalidateMostRecentCalls = 0;

  String _key(String accountId, int year, int month) =>
      '${accountId}_${year}_$month';

  @override
  Future<AccountBudget?> loadRevenue(
    String accountId,
    int year,
    int month, {
    bool forceRefresh = false,
    void Function(AccountBudget?)? onRevalidated,
  }) async => values[_key(accountId, year, month)];

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
  Future<double?> getMostRecentRevenue(
    String accountId, {
    required Period before,
  }) async => mostRecentRevenue;

  @override
  void invalidateMostRecentRevenueCache() => invalidateMostRecentCalls++;
}

ProviderContainer _makeContainer(_FakeAccountBudgetsService service) {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      accountBudgetsServiceProvider.overrideWithValue(service),
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      profileServiceProvider.overrideWithValue(_FakeProfileService()),
    ],
  );
}

void main() {
  const period = Period(year: 2026, month: 3);

  test(
    'load pulls the revenue for the period into shared state and exposes it',
    () async {
      final service = _FakeAccountBudgetsService({
        'a1_2026_3': const AccountBudget(
          accountId: 'a1',
          year: 2026,
          month: 3,
          revenue: 2000,
        ),
      });
      final container = _makeContainer(service);
      addTearDown(container.dispose);

      final notifier = container.read(revenueProvider('a1', period).notifier);
      await notifier.load();

      final state = container.read(revenueProvider('a1', period));
      expect(state.revenue, 2000);
      expect(state.hasRevenue, isTrue);
      expect(state.isLoaded, isTrue);
      // AccountBudgetsSession — the shared state other pages read — was
      // updated too, not just this page-local provider.
      expect(
        container
            .read(accountBudgetsSessionProvider.notifier)
            .getRevenue('a1', 2026, 3),
        2000,
      );
    },
  );

  test(
    'with no revenue set, falls back to the most recent past revenue as an estimate',
    () async {
      final service = _FakeAccountBudgetsService({
        'a1_2026_3': null,
      }, mostRecentRevenue: 1500);
      final container = _makeContainer(service);
      addTearDown(container.dispose);

      final notifier = container.read(revenueProvider('a1', period).notifier);
      await notifier.load();

      final state = container.read(revenueProvider('a1', period));
      expect(state.hasRevenue, isFalse);
      expect(state.isEstimated, isTrue);
      expect(state.effectiveRevenue, 1500);
      expect(state.showEditor, isTrue);
    },
  );

  test(
    'setRevenue writes through AccountBudgetsSession and closes the editor',
    () async {
      final service = _FakeAccountBudgetsService({});
      final container = _makeContainer(service);
      addTearDown(container.dispose);

      final notifier = container.read(revenueProvider('a1', period).notifier);
      notifier.openEditor();
      expect(container.read(revenueProvider('a1', period)).showEditor, isTrue);

      await notifier.setRevenue(3000);

      final state = container.read(revenueProvider('a1', period));
      expect(state.revenue, 3000);
      expect(state.showEditor, isFalse);
      expect(
        container
            .read(accountBudgetsSessionProvider.notifier)
            .getRevenue('a1', 2026, 3),
        3000,
      );
    },
  );

  test(
    'updating the same account/period in AccountBudgetsSession from elsewhere refreshes this provider',
    () async {
      final service = _FakeAccountBudgetsService({});
      final container = _makeContainer(service);
      addTearDown(container.dispose);

      // Make sure the provider exists before another part of the app writes
      // to the shared session, the way two widgets on the same screen would.
      container.read(revenueProvider('a1', period));

      await container
          .read(accountBudgetsSessionProvider.notifier)
          .setRevenue('a1', 2026, 3, 4200);

      expect(container.read(revenueProvider('a1', period)).revenue, 4200);
    },
  );
}
