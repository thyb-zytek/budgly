import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/cleanup/deletion_cleanup_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/sync_bootstrap_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_manager_provider.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A minimal ProfileService fake: the real one reaches for Firebase, which is
/// unavailable in `flutter test`. Only `registerSyncHandler` (inherited, not
/// overridden) matters here.
class _FakeProfileService extends ProfileService {
  _FakeProfileService({
    required super.analytics,
    required super.syncManager,
    required super.syncQueue,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Regression guard (see audit finding D-syncBootstrap): every service that
  /// owns a durable queue entity type must be wired to the single
  /// [SyncManager] by the composition root, or its pending mutations would
  /// silently never be replayed.
  test('registers a handler for every durable queue entity type', () async {
    SharedPreferences.setMockInitialValues({});
    final analytics = AnalyticsService();
    final syncQueue = SyncQueue();
    final syncManager = SyncManager(queue: syncQueue, analytics: analytics);
    addTearDown(syncManager.resetForTest);

    final accounts = AccountsService(
      analytics: analytics,
      syncManager: syncManager,
      syncQueue: syncQueue,
    );
    final categories = CategoriesService(
      analytics: analytics,
      syncManager: syncManager,
      syncQueue: syncQueue,
    );
    final expenses = ExpensesService(analytics: analytics);
    final budgets = AccountBudgetsService(analytics: analytics);

    final container = ProviderContainer(
      overrides: [
        syncManagerProvider.overrideWithValue(syncManager),
        accountsServiceProvider.overrideWithValue(accounts),
        categoriesServiceProvider.overrideWithValue(categories),
        expensesServiceProvider.overrideWithValue(expenses),
        accountBudgetsServiceProvider.overrideWithValue(budgets),
        profileServiceProvider.overrideWithValue(
          _FakeProfileService(
            analytics: analytics,
            syncManager: syncManager,
            syncQueue: syncQueue,
          ),
        ),
        deletionCleanupServiceProvider.overrideWithValue(
          DeletionCleanupService(
            expenses: expenses,
            budgets: budgets,
            accounts: accounts,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(syncBootstrapProvider);

    expect(syncManager.registeredHandlerTypes, {
      'accounts',
      'categories',
      'expenses',
      'user_profiles',
      'cleanup',
    });
  });
}
