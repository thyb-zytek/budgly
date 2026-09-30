import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/pages/tutorial/tutorial_provider.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_manager_provider.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
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
}

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

  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async => values;
}

class _FakeCategoriesService extends CategoriesService {
  _FakeCategoriesService({
    this.availableIcons = const [],
    this.byAccount = const {},
  }) : super(
         analytics: AnalyticsService(),
         syncManager: SyncManager(
           queue: SyncQueue(),
           analytics: AnalyticsService(),
         ),
         syncQueue: SyncQueue(),
       );

  final List<CategoryIcon> availableIcons;
  final Map<String, List<Category>> byAccount;

  @override
  Future<List<CategoryIcon>> loadAvailableIcons({
    bool forceRefresh = false,
  }) async => availableIcons;

  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
    void Function(List<Category>)? onRevalidated,
  }) async => byAccount[accountId] ?? const [];
}

class _FakeAccountBudgetsService extends AccountBudgetsService {
  _FakeAccountBudgetsService({this.revenueByAccount = const {}})
    : super(analytics: AnalyticsService());

  final Map<String, double> revenueByAccount;
  double? mostRecentRevenue;

  @override
  Future<AccountBudget?> loadRevenue(
    String accountId,
    int year,
    int month, {
    bool forceRefresh = false,
    void Function(AccountBudget?)? onRevalidated,
  }) async {
    final revenue = revenueByAccount[accountId];
    return revenue == null
        ? null
        : AccountBudget(
            accountId: accountId,
            year: year,
            month: month,
            revenue: revenue,
          );
  }

  @override
  Future<double?> getMostRecentRevenue(
    String accountId, {
    required Period before,
  }) async => mostRecentRevenue;
}

ProviderContainer _makeContainer({
  _FakeAccountsService? accounts,
  _FakeCategoriesService? categories,
  _FakeAccountBudgetsService? accountBudgets,
}) {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      profileServiceProvider.overrideWithValue(_FakeProfileService()),
      accountsServiceProvider.overrideWithValue(
        accounts ?? _FakeAccountsService(const []),
      ),
      categoriesServiceProvider.overrideWithValue(
        categories ?? _FakeCategoriesService(),
      ),
      accountBudgetsServiceProvider.overrideWithValue(
        accountBudgets ?? _FakeAccountBudgetsService(),
      ),
      analyticsServiceProvider.overrideWithValue(AnalyticsService()),
      syncManagerProvider.overrideWithValue(
        SyncManager(queue: SyncQueue(), analytics: AnalyticsService()),
      ),
      syncQueueProvider.overrideWithValue(SyncQueue()),
    ],
  );
  // Keep tutorialProvider alive so the async initialization completes,
  // mirroring the TutorialPage widget that watches it in production.
  container.listen(tutorialProvider, (_, _) {});
  return container;
}

Future<void> _waitForInitialization(ProviderContainer container) async {
  final tutorial = container.read(tutorialProvider);
  if (!tutorial.isInitializing) return;
  // Wait for initialization to complete by checking state
  await Future.delayed(const Duration(milliseconds: 100));
  while (container.read(tutorialProvider).isInitializing) {
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  const existingAccount = Account(id: 'a1', name: 'Compte existant');

  test(
    'connecting a user with an existing account loads accounts, icons, categories and revenue into every session',
    () async {
      final fakeCategories = _FakeCategoriesService(
        availableIcons: [
          CategoryIcon(
            iconName: 'shopping',
            iconCode: 0xe587,
            iconPack: 'MaterialIcons',
            labels: {'en': 'Shopping', 'fr': 'Courses'},
          ),
          CategoryIcon(
            iconName: 'transport',
            iconCode: 0xe530,
            iconPack: 'MaterialIcons',
            labels: {'en': 'Transport', 'fr': 'Transport'},
          ),
        ],
        byAccount: {
          'a1': const [Category(id: 'c1', name: 'Courses', accountId: 'a1')],
        },
      );
      final fakeBudgets = _FakeAccountBudgetsService(
        revenueByAccount: {'a1': 2500},
      );

      final container = _makeContainer(
        accounts: _FakeAccountsService([existingAccount]),
        categories: fakeCategories,
        accountBudgets: fakeBudgets,
      );
      addTearDown(container.dispose);

      await _waitForInitialization(container);

      // Bug 1 regression: at connection the sessions must be populated so a
      // reload of the app does not lose the data.
      expect(container.read(accountsSessionProvider).accounts, hasLength(1));
      expect(
        container.read(categoriesSessionProvider).availableIcons,
        hasLength(2),
      );
      expect(
        container
            .read(categoriesSessionProvider.notifier)
            .getCategoriesForAccount('a1'),
        hasLength(1),
      );
      expect(container.read(tutorialProvider).createdAccount?.id, 'a1');
      expect(container.read(tutorialProvider).hasRevenue, isTrue);
    },
  );

  test(
    'connecting a brand-new user still loads accounts and category icons (empty adopt is skipped)',
    () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await _waitForInitialization(container);

      expect(container.read(accountsSessionProvider).accounts, isEmpty);
      expect(container.read(tutorialProvider).createdAccount, isNull);
      expect(container.read(tutorialProvider).isInitializing, isFalse);
    },
  );
}
