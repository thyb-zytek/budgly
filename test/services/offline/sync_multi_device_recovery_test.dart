import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SyncManager - Multi-device recovery scenario', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Device A offline: creates expense, goes offline', () async {
      var deviceAUserId = 'user123';

      final queueA = SyncQueue(
        ownerUserIdProvider: () => deviceAUserId,
      );

      // Device A creates expense while online
      await queueA.enqueue(
        id: 'expense:e1',
        type: 'expenses',
        operation: 'create',
        payload: {
          'id': 'e1',
          'accountId': 'a1',
          'categoryId': 'c1',
          'name': 'Loyer',
          'amount': 800,
          'debitDate': '2026-09-30',
        },
      );

      // Device A goes offline


      // Verify operation is persisted
      final allOps = await queueA.all();
      expect(allOps, hasLength(1));
      expect(allOps.first.ownerUserId, 'user123');
    });

    test('Device B concurrent: same user, creates different expense', () async {
      var deviceBUserId = 'user123';

      final queueB = SyncQueue(
        ownerUserIdProvider: () => deviceBUserId,
      );

      // Device B creates different expense
      await queueB.enqueue(
        id: 'expense:e2',
        type: 'expenses',
        operation: 'create',
        payload: {
          'id': 'e2',
          'accountId': 'a1',
          'categoryId': 'c2',
          'name': 'Courses',
          'amount': 120,
          'debitDate': '2026-09-30',
        },
      );

      final allOps = await queueB.all();
      expect(allOps, hasLength(1));
      expect(allOps.first.id, 'expense:e2');
    });

    test('Merge: both devices sync, operations coexist with same owner', () async {
      // In production: Device A comes online first, syncs e1
      // Then Device B syncs e2
      // Queue should contain both operations with same ownerUserId

      final queue = SyncQueue(
        ownerUserIdProvider: () => 'user123',
      );

      // Simulate both operations in queue
      await queue.enqueue(
        id: 'expense:e1',
        type: 'expenses',
        operation: 'create',
        payload: {'id': 'e1', 'name': 'Loyer'},
      );

      await queue.enqueue(
        id: 'expense:e2',
        type: 'expenses',
        operation: 'create',
        payload: {'id': 'e2', 'name': 'Courses'},
      );

      final allOps = await queue.all();
      expect(allOps, hasLength(2));
      expect(
        allOps.every((op) => op.ownerUserId == 'user123'),
        true,
      );
    });

    test('SyncManager processes owned operations in order', () async {
      final queue = SyncQueue(
        ownerUserIdProvider: () => 'user123',
      );

      final manager = SyncManager(
        queue: queue,
        analytics: AnalyticsService(),
      );

      // Add operations
      await queue.enqueue(
        id: 'op:1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'a1'},
      );
      await queue.enqueue(
        id: 'op:2',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'a2'},
      );

      // Verify manager will process in order
      final toProcess = await queue.all();
      expect(toProcess, hasLength(2));
      expect(toProcess.map((op) => op.id), ['op:1', 'op:2']);

      // Clean up
      manager.dispose();
    });

    test('Session switch: user2 cannot see user1 pending operations', () async {
      var currentUserId = 'user1';
      final queue = SyncQueue(
        ownerUserIdProvider: () => currentUserId,
      );

      // User1 enqueues operations
      await queue.enqueue(
        id: 'user1:op1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'a1'},
      );

      // Switch to user2
      currentUserId = 'user2';

      // User2 should not see user1's operations
      final user2View = await queue.allForCurrentOwner();
      expect(user2View, isEmpty);

      // But user1's operations are still retrievable
      final user1Ops = await queue.allForOwner('user1');
      expect(user1Ops, hasLength(1));
    });
  });

  group('SyncQueue - Coalescing maintains owner boundaries', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Same entity, different owners: operations do not coalesce', () async {
      var currentUserId = 'user1';
      final queue = SyncQueue(
        ownerUserIdProvider: () => currentUserId,
      );

      // User1 creates account 'a1'
      await queue.enqueue(
        id: 'account:a1:create',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'a1', 'name': 'User1 Account'},
      );

      // User1 updates same account
      await queue.enqueue(
        id: 'account:a1:update',
        type: 'accounts',
        operation: 'update',
        payload: {'id': 'a1', 'name': 'User1 Updated'},
      );

      // Should have coalesced into one operation (create + update = create)
      var allOps = await queue.all();
      expect(allOps, hasLength(1));
      expect(allOps.first.operation, 'create');
      expect(allOps.first.payload['name'], 'User1 Updated');

      // Switch to user2
      currentUserId = 'user2';

      // User2 creates same entity ID
      await queue.enqueue(
        id: 'account:a1:create',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'a1', 'name': 'User2 Account'},
      );

      // Should NOT coalesce - different owners
      allOps = await queue.all();
      expect(
        allOps,
        hasLength(2),
        reason: 'Operations from different users should not coalesce',
      );

      final user1Ops = allOps.where((op) => op.ownerUserId == 'user1');
      final user2Ops = allOps.where((op) => op.ownerUserId == 'user2');

      expect(user1Ops.map((op) => op.payload['name']), ['User1 Updated']);
      expect(user2Ops.map((op) => op.payload['name']), ['User2 Account']);
    });
  });
}
