import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// Regression coverage for the logout orchestration split (see
/// docs/AUDIT_PLAN.md, X3): `ProfileService.signOut` only handles auth/sync
/// and no longer knows about accounts/categories/expenses/budgets at all.
/// Each session's own `clear()` invalidates its service's cache
/// (`AccountsSession`/`CategoriesSession`/`ExpensesSession`/
/// `AccountBudgetsSession.clear()`); `ProfileSession.signOut` (this notifier,
/// the composition root) only has to clear every session.

/// `AuthService.signOut` also calls `GoogleSignIn.instance.signOut()`, and
/// `GoogleSignIn` only has a library-private constructor, so the platform
/// channel it needs cannot be replaced from a test. The Firebase half of the
/// sign-out stays real here; only the Google call is skipped, since the auth
/// provider's own error handling is covered by the auth service tests and is
/// not what the orchestration contract below is about.
class _FakeAuthService extends AuthService {
  _FakeAuthService(this.firebase, {required super.analytics})
    : super(auth: firebase);

  final MockFirebaseAuth firebase;

  @override
  Future<void> signOut() => firebase.signOut();
}

class _FakeProfileService extends ProfileService {
  _FakeProfileService({required super.authService})
    : super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );
}

class _TrackingAccountsService extends AccountsService {
  _TrackingAccountsService()
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );

  bool cleared = false;

  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async => const [];

  @override
  void clearLocalAccounts() {
    cleared = true;
    super.clearLocalAccounts();
  }
}

class _TrackingCategoriesService extends CategoriesService {
  _TrackingCategoriesService()
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );

  bool cleared = false;

  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
    void Function(List<Category>)? onRevalidated,
  }) async => const [];

  @override
  void invalidateCache() {
    cleared = true;
    super.invalidateCache();
  }
}

class _TrackingExpensesService extends ExpensesService {
  _TrackingExpensesService() : super(analytics: AnalyticsService());

  bool cleared = false;

  @override
  void invalidateCache() {
    cleared = true;
    super.invalidateCache();
  }
}

class _TrackingBudgetsService extends AccountBudgetsService {
  _TrackingBudgetsService() : super(analytics: AnalyticsService());

  bool cleared = false;

  @override
  void invalidateCache() {
    cleared = true;
    super.invalidateCache();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'signOut invalidates every service cache and clears every session',
    () async {
      final auth = _FakeAuthService(
        MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'user-a')),
        analytics: AnalyticsService(),
      );
      final accounts = _TrackingAccountsService();
      final categories = _TrackingCategoriesService();
      final expenses = _TrackingExpensesService();
      final budgets = _TrackingBudgetsService();

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          profileServiceProvider.overrideWithValue(
            _FakeProfileService(authService: auth),
          ),
          accountsServiceProvider.overrideWithValue(accounts),
          categoriesServiceProvider.overrideWithValue(categories),
          expensesServiceProvider.overrideWithValue(expenses),
          accountBudgetsServiceProvider.overrideWithValue(budgets),
        ],
      );
      addTearDown(container.dispose);

      // Populate every session so we can observe it being cleared.
      await container.read(accountsSessionProvider.notifier).load();
      await container.read(categoriesSessionProvider.notifier).load('a1');

      await container.read(profileSessionProvider.notifier).signOut();

      expect(accounts.cleared, isTrue);
      expect(categories.cleared, isTrue);
      expect(expenses.cleared, isTrue);
      expect(budgets.cleared, isTrue);

      expect(container.read(accountsSessionProvider).hasLoaded, isFalse);
      expect(container.read(categoriesSessionProvider).loadedAccounts, isEmpty);
      expect(container.read(profileSessionProvider).currentUser, isNull);
    },
  );
}
