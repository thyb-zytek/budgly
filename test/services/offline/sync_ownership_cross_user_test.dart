import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SyncQueue - Cross-user ownership isolation', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('enqueue() rejects mutation without authenticated user', () async {
      final queue = SyncQueue(
        ownerUserIdProvider: () => null, // No user
      );

      expect(
        () => queue.enqueue(
          id: 'test:1',
          type: 'accounts',
          operation: 'create',
          payload: {'id': 'a1', 'name': 'Account'},
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('authenticated user'),
          ),
        ),
      );
    });

    test('enqueue() captures ownerUserId at mutation time', () async {
      var currentUserId = 'user1';
      final queue = SyncQueue(ownerUserIdProvider: () => currentUserId);

      // User1 enqueues mutation
      await queue.enqueue(
        id: 'test:1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'a1', 'name': 'Account1'},
      );

      // Verify ownership
      final allOps = await queue.all();
      expect(allOps, hasLength(1));
      expect(allOps.first.ownerUserId, 'user1');

      // User2 logs in (different session)
      currentUserId = 'user2';

      // Queue still contains user1's operation
      final user2View = await queue.allForCurrentOwner();
      expect(
        user2View,
        isEmpty,
        reason: 'user2 should not see user1 operations',
      );

      // But user1 operations are still retrievable by explicit owner query
      final user1Ops = await queue.allForOwner('user1');
      expect(user1Ops, hasLength(1));
    });

    test('allForCurrentOwner() filters by session ownership', () async {
      var currentUserId = 'user1';
      final queue = SyncQueue(ownerUserIdProvider: () => currentUserId);

      // User1 enqueues 2 operations
      await queue.enqueue(
        id: 'test:1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'a1', 'name': 'Account1'},
      );
      await queue.enqueue(
        id: 'test:2',
        type: 'categories',
        operation: 'create',
        payload: {'id': 'c1', 'name': 'Category1'},
      );

      // Switch to user2
      currentUserId = 'user2';

      // User2 sees no operations (all belong to user1)
      final user2Owned = await queue.allForCurrentOwner();
      expect(user2Owned, isEmpty);

      // User2 enqueues their own operation
      await queue.enqueue(
        id: 'test:3',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'a2', 'name': 'Account2'},
      );

      // Switch back to user1
      currentUserId = 'user1';

      // User1 sees only their operations
      final user1Owned = await queue.allForCurrentOwner();
      expect(user1Owned, hasLength(2));
      expect(user1Owned.every((op) => op.ownerUserId == 'user1'), true);
    });

    test(
      'coalescing respects ownerUserId (same entity, different users)',
      () async {
        var currentUserId = 'user1';
        final queue = SyncQueue(ownerUserIdProvider: () => currentUserId);

        // User1 creates account 'a1'
        await queue.enqueue(
          id: 'account:a1',
          type: 'accounts',
          operation: 'create',
          payload: {'id': 'a1', 'name': 'User1 Account'},
        );

        // Switch to user2
        currentUserId = 'user2';

        // User2 creates account 'a1' (same ID, different owner)
        await queue.enqueue(
          id: 'account:a1',
          type: 'accounts',
          operation: 'create',
          payload: {'id': 'a1', 'name': 'User2 Account'},
        );

        // Both operations should exist (not coalesced across users)
        final allOps = await queue.all();
        expect(allOps, hasLength(2));

        final user1Ops = await queue.allForOwner('user1');
        final user2Ops = await queue.allForOwner('user2');

        expect(user1Ops, hasLength(1));
        expect(user2Ops, hasLength(1));
        expect(user1Ops.first.payload['name'], 'User1 Account');
        expect(user2Ops.first.payload['name'], 'User2 Account');
      },
    );

    test(
      'update on same entity by different users does not coalesce',
      () async {
        var currentUserId = 'user1';
        final queue = SyncQueue(ownerUserIdProvider: () => currentUserId);

        // User1 creates, then updates
        await queue.enqueue(
          id: 'account:a1',
          type: 'accounts',
          operation: 'create',
          payload: {'id': 'a1', 'name': 'Original'},
        );
        await queue.enqueue(
          id: 'account:a1:update',
          type: 'accounts',
          operation: 'update',
          payload: {'id': 'a1', 'name': 'Updated by User1'},
        );

        // Switch to user2
        currentUserId = 'user2';

        // User2 creates same entity
        await queue.enqueue(
          id: 'account:a1',
          type: 'accounts',
          operation: 'create',
          payload: {'id': 'a1', 'name': 'User2 Original'},
        );

        final allOps = await queue.all();
        // Should have: user1 create (merged with their update), user2 create
        expect(allOps, hasLength(2));

        final user1Ops = await queue.allForOwner('user1');
        expect(user1Ops, hasLength(1));
        expect(
          user1Ops.first.operation,
          'create',
          reason: 'create+update coalesced',
        );
        expect(user1Ops.first.payload['name'], 'Updated by User1');
      },
    );
  });
}
