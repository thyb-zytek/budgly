import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
  });

  tearDown(() async {
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
  });

  test(
    'test reset removes handlers and stuck state from the test coordinator',
    () async {
      final queue = testSyncQueue;
      await queue.enqueue(
        id: 'reset-1',
        type: 'reset-test',
        operation: 'update',
        payload: {'id': 'e1'},
      );
      for (var i = 0; i < SyncManager.stuckAfterAttempts; i++) {
        await queue.markFailed('reset-1');
      }

      testSyncManager.registerHandler('reset-test', (_) async {});
      await testSyncManager.flush();
      expect(testSyncManager.hasStuckOperations, isTrue);

      await testSyncManager.resetForTest();
      expect(testSyncManager.hasStuckOperations, isFalse);
      expect(testSyncManager.stuckOperationsCount, 0);

      await testSyncManager.flush(forceRetry: true);
      expect(await queue.hasPending(type: 'reset-test'), isTrue);
    },
  );

  test('forceRetry drains a pending operation inside backoff', () async {
    final queue = testSyncQueue;
    await queue.enqueue(
      id: 'contract-1',
      type: 'contract',
      operation: 'update',
      payload: {'id': 'e1'},
    );
    await queue.markFailed('contract-1');

    var calls = 0;
    testSyncManager.registerHandler('contract', (_) async {
      calls++;
    });

    await testSyncManager.flush();
    expect(calls, 0);
    expect(await queue.all(), hasLength(1));

    await testSyncManager.flush(forceRetry: true);

    expect(calls, 1);
    expect(await queue.all(), isEmpty);
  });

  test('a pending parent blocks dependent expense replay', () async {
    final queue = testSyncQueue;
    await queue.enqueue(
      id: 'account',
      type: 'accounts',
      operation: 'update',
      payload: {'id': 'a1'},
    );
    await queue.enqueue(
      id: 'expense',
      type: 'expenses',
      operation: 'update',
      payload: {
        'id': 'e1',
        'accountId': 'a1',
        'categoryId': 'c1',
        'name': 'x',
        'amount': 1,
        'debitDate': '2026-03-01T00:00:00.000',
        'recurrence': 'none',
        'recurrenceAnchorDay': 1,
        'isDebited': false,
        'debitedOccurrences': [],
      },
    );
    await queue.markFailed('account');

    var expenseCalls = 0;
    testSyncManager.registerHandler('accounts', (_) async {});
    testSyncManager.registerHandler('expenses', (_) async {
      expenseCalls++;
    });

    await testSyncManager.flush();

    expect(expenseCalls, 0);
    expect(await queue.hasPending(type: 'expenses', entityId: 'e1'), isTrue);
  });

  test('a failed account only blocks dependents of that account', () async {
    final queue = testSyncQueue;
    await queue.enqueue(
      id: 'account-a',
      type: 'accounts',
      operation: 'update',
      payload: {'id': 'a'},
    );
    await queue.enqueue(
      id: 'account-b',
      type: 'accounts',
      operation: 'update',
      payload: {'id': 'b'},
    );
    await queue.enqueue(
      id: 'category-a',
      type: 'categories',
      operation: 'update',
      payload: {'id': 'ca', 'account_id': 'a'},
    );
    await queue.enqueue(
      id: 'category-b',
      type: 'categories',
      operation: 'update',
      payload: {'id': 'cb', 'account_id': 'b'},
    );

    final calls = <String>[];
    testSyncManager.registerHandler('accounts', (operation) async {
      calls.add(operation.entityId);
      if (operation.entityId == 'a') throw StateError('offline');
    });
    testSyncManager.registerHandler('categories', (operation) async {
      calls.add(operation.entityId);
    });

    await testSyncManager.flush();

    expect(calls, ['a', 'b', 'cb']);
    expect(await queue.hasPending(type: 'categories', entityId: 'ca'), isTrue);
    expect(await queue.hasPending(type: 'categories', entityId: 'cb'), isFalse);
  });

  test('a failed operation does not block an unrelated entity', () async {
    final queue = testSyncQueue;
    await queue.enqueue(
      id: 'a',
      type: 'contract',
      operation: 'update',
      payload: {'id': 'a'},
    );
    await queue.enqueue(
      id: 'b',
      type: 'contract',
      operation: 'update',
      payload: {'id': 'b'},
    );

    final calls = <String>[];
    testSyncManager.registerHandler('contract', (operation) async {
      calls.add(operation.entityId);
      if (operation.entityId == 'a') throw StateError('offline');
    });

    await testSyncManager.flush();

    expect(calls, ['a', 'b']);
    expect((await queue.all()).map((e) => e.entityId), ['a']);
  });
  test(
    'replays only mutations owned by the current authenticated user',
    () async {
      var currentUserId = 'user-a';
      final queue = SyncQueue(ownerUserIdProvider: () => currentUserId);
      final manager = SyncManager(
        queue: queue,
        analytics: AnalyticsService(),
        ownerUserIdProvider: () => currentUserId,
      );
      addTearDown(manager.resetForTest);

      await queue.enqueue(
        id: 'a',
        type: 'contract',
        operation: 'update',
        payload: {'id': 'a'},
      );
      currentUserId = 'user-b';
      await queue.enqueue(
        id: 'b',
        type: 'contract',
        operation: 'update',
        payload: {'id': 'b'},
      );

      final calls = <String>[];
      manager.registerHandler('contract', (operation) async {
        calls.add(operation.entityId);
      });
      await manager.flush(forceRetry: true);

      expect(calls, ['b']);
      expect(
        (await queue.all()).map((operation) => operation.entityId).toSet(),
        {'a'},
      );

      currentUserId = 'user-a';
      await manager.flush(forceRetry: true);
      expect(calls, ['b', 'a']);
      expect(await queue.all(), isEmpty);
    },
  );

  test(
    'does not replay queued mutations while the authentication session is absent',
    () async {
      String? currentUserId = 'user-a';
      final queue = SyncQueue(ownerUserIdProvider: () => currentUserId);
      final manager = SyncManager(
        queue: queue,
        analytics: AnalyticsService(),
        ownerUserIdProvider: () => currentUserId,
      );
      addTearDown(manager.resetForTest);

      await queue.enqueue(
        id: 'a',
        type: 'contract',
        operation: 'update',
        payload: {'id': 'a'},
      );
      currentUserId = null;

      var calls = 0;
      manager.registerHandler('contract', (_) async => calls++);
      await manager.flush(forceRetry: true);

      expect(calls, 0);
      expect(await queue.all(), hasLength(1));
    },
  );

  test(
    'stops an in-flight replay pass when the authenticated user changes',
    () async {
      String? currentUserId = 'user-a';
      final queue = SyncQueue(ownerUserIdProvider: () => currentUserId);
      final manager = SyncManager(
        queue: queue,
        analytics: AnalyticsService(),
        ownerUserIdProvider: () => currentUserId,
      );
      addTearDown(manager.resetForTest);

      await queue.enqueue(
        id: 'a1',
        type: 'contract',
        operation: 'update',
        payload: {'id': 'a1'},
      );
      await queue.enqueue(
        id: 'a2',
        type: 'contract',
        operation: 'update',
        payload: {'id': 'a2'},
      );

      final calls = <String>[];
      manager.registerHandler('contract', (operation) async {
        calls.add(operation.entityId);
        currentUserId = 'user-b';
      });

      await manager.flush(forceRetry: true);

      expect(calls, ['a1']);
      expect(
        (await queue.all()).map((operation) => operation.entityId).toSet(),
        {'a2'},
      );
    },
  );
}
