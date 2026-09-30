import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/cleanup/deletion_cleanup_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeExpenses extends ExpensesService {
  _FakeExpenses() : super(analytics: AnalyticsService());

  final purgedAccountIds = <String>[];
  final purgedCategoryIds = <String>[];
  bool throwOnAccountPurge = false;

  @override
  Future<void> purgeByAccountId(String accountId) async {
    if (throwOnAccountPurge) throw StateError('offline');
    purgedAccountIds.add(accountId);
  }

  @override
  Future<void> purgeByCategoryId(String categoryId) async {
    purgedCategoryIds.add(categoryId);
  }
}

class _FakeBudgets extends AccountBudgetsService {
  _FakeBudgets() : super(analytics: AnalyticsService());

  final purgedAccountIds = <String>[];

  @override
  Future<void> purgeByAccountId(String accountId) async {
    purgedAccountIds.add(accountId);
  }
}

class _FakeAccounts extends AccountsService {
  _FakeAccounts({required super.syncManager, required super.syncQueue})
    : super(analytics: AnalyticsService());

  final deletedFolderIds = <String>[];

  @override
  Future<void> deleteAccountFolder(
    String accountId, {
    bool throwOnFailure = false,
  }) async {
    deletedFolderIds.add(accountId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncQueue queue;
  late SyncManager manager;
  late _FakeExpenses expenses;
  late _FakeBudgets budgets;
  late _FakeAccounts accounts;
  late DeletionCleanupService cleanup;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    queue = SyncQueue();
    manager = SyncManager(queue: queue, analytics: AnalyticsService());
    expenses = _FakeExpenses();
    budgets = _FakeBudgets();
    accounts = _FakeAccounts(syncManager: manager, syncQueue: queue);
    cleanup = DeletionCleanupService(
      expenses: expenses,
      budgets: budgets,
      accounts: accounts,
    );
    cleanup.registerSyncHandler(manager);
  });

  tearDown(() async {
    await manager.resetForTest();
    await queue.clear();
  });

  test(
    'an account cleanup purges expenses, budgets and the storage folder',
    () async {
      await queue.enqueue(
        id: 'cleanup:account:a1',
        type: 'cleanup',
        operation: 'account',
        payload: {'id': 'a1'},
      );

      await manager.flush(forceRetry: true);

      expect(expenses.purgedAccountIds, ['a1']);
      expect(budgets.purgedAccountIds, ['a1']);
      expect(accounts.deletedFolderIds, ['a1']);
      expect(await queue.all(), isEmpty);
    },
  );

  test('a category cleanup purges its expenses', () async {
    await queue.enqueue(
      id: 'cleanup:category:c1',
      type: 'cleanup',
      operation: 'category',
      payload: {'id': 'c1'},
    );

    await manager.flush(forceRetry: true);

    expect(expenses.purgedCategoryIds, ['c1']);
    expect(await queue.all(), isEmpty);
  });

  test(
    'a failed step is retried and never leaves the operation silently dropped',
    () async {
      expenses.throwOnAccountPurge = true;
      await queue.enqueue(
        id: 'cleanup:account:a1',
        type: 'cleanup',
        operation: 'account',
        payload: {'id': 'a1'},
      );

      await manager.flush(forceRetry: true);
      expect(await queue.all(), hasLength(1));
      expect(
        budgets.purgedAccountIds,
        isEmpty,
        reason: 'must not partially advance past the failed step',
      );

      expenses.throwOnAccountPurge = false;
      await manager.flush(forceRetry: true);

      expect(await queue.all(), isEmpty);
      expect(budgets.purgedAccountIds, ['a1']);
    },
  );
}
