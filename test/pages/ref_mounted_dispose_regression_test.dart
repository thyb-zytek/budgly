import 'dart:async';

import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/pages/category_expenses/category_expenses_provider.dart';
import 'package:budgly/src/pages/settings/accounts/accounts_settings_provider.dart';
import 'package:budgly/src/pages/settings/categories/categories_settings_provider.dart';
import 'package:budgly/src/pages/settings/profile/profile_settings_provider.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for phase 5 of the audit (docs/AUDIT_PLAN.md, R1):
/// several `@riverpod` notifiers wrote to `state` after an `await` without
/// checking `ref.mounted` first. An autoDispose notifier can be disposed
/// (screen popped, family key no longer watched) while one of its async
/// methods is still waiting on a network call; without the guard, resuming
/// after dispose throws instead of silently doing nothing.
///
/// Each test starts an async method whose underlying service call is a
/// `Completer` under the test's control, disposes the provider container
/// *while that call is still in flight*, then lets it complete — and asserts
/// this does not throw. Before the phase 5 fix, every one of these would
/// throw a "Bad state" / "Cannot use a ref after it has been disposed" error.

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(analytics: AnalyticsService());
  @override
  User? get currentUser => null;
  @override
  fb.User? get firebaseUser => null;
}

class _FakeProfileService extends ProfileService {
  _FakeProfileService({
    required super.analytics,
    required super.syncManager,
    required super.syncQueue,
    this._changePassword,
  });

  final Future<User> Function(String, String)? _changePassword;

  @override
  Future<
    ({
      ThemeMode themeMode,
      Locale locale,
      String currency,
      int amountDecimalPlaces,
    })
  >
  loadLocalPreferences({required String? uid}) async => (
    themeMode: ThemeMode.system,
    locale: const Locale('fr'),
    currency: 'EUR',
    amountDecimalPlaces: 2,
  );

  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async => null;

  @override
  Future<User?> refreshFromServer() async => null;

  @override
  Future<User> changePassword(String oldPassword, String newPassword) =>
      _changePassword!(oldPassword, newPassword);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'CategoryExpenses.loadMore does not throw when disposed mid-flight',
    () async {
      final completer = Completer<ExpensePage>();
      final analytics = AnalyticsService();
      final syncQueue = SyncQueue();
      final syncManager = SyncManager(queue: syncQueue, analytics: analytics);

      final expenses = _PendingPageExpensesService(
        completer,
        analytics: analytics,
      );
      final container = ProviderContainer(
        overrides: [
          expensesServiceProvider.overrideWithValue(expenses),
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          profileServiceProvider.overrideWithValue(
            _FakeProfileService(
              analytics: analytics,
              syncManager: syncManager,
              syncQueue: syncQueue,
            ),
          ),
        ],
      );

      const period = Period(year: 2026, month: 3);
      final notifier = container.read(
        categoryExpensesProvider('a1', 'c1', period).notifier,
      );
      final loadMore = notifier.loadMore();

      container.dispose();
      completer.complete(
        const ExpensePage(expenses: [], cursor: null, hasMore: false),
      );

      await expectLater(loadMore, completes);
    },
  );

  test(
    'AccountsSettings.loadAccounts does not throw when disposed mid-flight',
    () async {
      final completer = Completer<List<Account>>();
      final accounts = _PendingAccountsService(completer);
      final container = ProviderContainer(
        overrides: [accountsServiceProvider.overrideWithValue(accounts)],
      );

      final notifier = container.read(accountsSettingsProvider.notifier);
      final loadAccounts = notifier.loadAccounts();

      container.dispose();
      completer.complete(const []);

      await expectLater(loadAccounts, completes);
    },
  );

  test(
    'CategoriesSettings.loadCategories does not throw when disposed mid-flight',
    () async {
      final completer = Completer<List<Category>>();
      final categories = _PendingCategoriesService(completer);
      final container = ProviderContainer(
        overrides: [categoriesServiceProvider.overrideWithValue(categories)],
      );

      final notifier = container.read(categoriesSettingsProvider.notifier);
      // selectAccount sets state.account and, since nothing is loaded yet,
      // fires an internal loadCategories() call too — harmless here since
      // both share the same pending completer; this second call is the one
      // we actually observe.
      notifier.selectAccount(const Account(id: 'a1', name: 'Main'));
      final loadCategories = notifier.loadCategories();

      container.dispose();
      completer.complete(const []);

      await expectLater(loadCategories, completes);
    },
  );

  test(
    'ProfileSettings.changePassword does not throw when disposed mid-flight',
    () async {
      final completer = Completer<User>();
      final analytics = AnalyticsService();
      final syncQueue = SyncQueue();
      final syncManager = SyncManager(queue: syncQueue, analytics: analytics);

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          profileServiceProvider.overrideWithValue(
            _FakeProfileService(
              analytics: analytics,
              syncManager: syncManager,
              syncQueue: syncQueue,
              changePassword: (oldPassword, newPassword) => completer.future,
            ),
          ),
        ],
      );

      final notifier = container.read(profileSettingsProvider.notifier);
      final changePassword = notifier.changePassword(
        oldPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      container.dispose();
      completer.complete(const User(id: 'user-a'));

      await expectLater(changePassword, completes);
    },
  );
}

class _PendingPageExpensesService extends ExpensesService {
  _PendingPageExpensesService(this._completer, {required super.analytics});
  final Completer<ExpensePage> _completer;

  @override
  Future<ExpensePage> listCategoryPeriodPage(
    String accountId,
    String categoryId,
    Period period, {
    int limit = 20,
    Object? startAfter,
    bool includeRecurring = true,
  }) => _completer.future;
}

class _PendingAccountsService extends AccountsService {
  _PendingAccountsService(this._completer)
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );
  final Completer<List<Account>> _completer;

  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) => _completer.future;
}

class _PendingCategoriesService extends CategoriesService {
  _PendingCategoriesService(this._completer)
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );
  final Completer<List<Category>> _completer;

  @override
  Future<List<CategoryIcon>> loadAvailableIcons() async => const [];

  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
    void Function(List<Category>)? onRevalidated,
  }) => _completer.future;
}
