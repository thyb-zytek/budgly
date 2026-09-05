import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SyncQueue queue;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    queue = SyncQueue.instance;
    await queue.clear();
  });

  group('PendingSync', () {
    test('entityId extracts from payload id', () {
      const sync = PendingSync(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'acc-1'},
      );
      expect(sync.entityId, 'acc-1');
    });

    test('entityId is empty string when payload has no id', () {
      const sync = PendingSync(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'name': 'Test'},
      );
      expect(sync.entityId, '');
    });

    test('isReady returns true when nextAttemptAt is null', () {
      const sync = PendingSync(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1'},
      );
      expect(sync.isReady, isTrue);
    });

    test('isReady returns true when nextAttemptAt is in the past', () {
      final sync = PendingSync(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1'},
        nextAttemptAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(sync.isReady, isTrue);
    });

    test('isReady returns false when nextAttemptAt is in the future', () {
      final sync = PendingSync(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1'},
        nextAttemptAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(sync.isReady, isFalse);
    });

    test('toJson and fromJson round trip', () {
      final sync = PendingSync(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'acc-1', 'name': 'Test'},
        attempts: 3,
        nextAttemptAt: DateTime(2026, 6, 15, 12, 0, 0),
      );

      final json = sync.toJson();
      final restored = PendingSync.fromJson(json);

      expect(restored.id, sync.id);
      expect(restored.type, sync.type);
      expect(restored.operation, sync.operation);
      expect(restored.payload, sync.payload);
      expect(restored.attempts, sync.attempts);
      expect(restored.nextAttemptAt, sync.nextAttemptAt);
    });

    test('fromJson handles null attempts', () {
      final json = {
        'id': 'op-1',
        'type': 'accounts',
        'operation': 'create',
        'payload': {'id': '1'},
        'attempts': null,
        'next_attempt_at': null,
      };
      final sync = PendingSync.fromJson(json);
      expect(sync.attempts, 0);
      expect(sync.nextAttemptAt, isNull);
    });

    test('copyWith preserves unmodified fields', () {
      final sync = PendingSync(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1'},
        attempts: 2,
        nextAttemptAt: DateTime(2026, 6, 15),
      );

      final copy = sync.copyWith(attempts: 5);
      expect(copy.id, sync.id);
      expect(copy.type, sync.type);
      expect(copy.operation, sync.operation);
      expect(copy.payload, sync.payload);
      expect(copy.attempts, 5);
      expect(copy.nextAttemptAt, sync.nextAttemptAt);
    });
  });

  group('SyncQueue enqueue edge cases', () {
    test('update followed by update replaces both with latest', () async {
      await queue.enqueue(
        id: 'op-1',
        type: 'accounts',
        operation: 'update',
        payload: {'id': '1', 'name': 'First'},
      );
      await queue.enqueue(
        id: 'op-2',
        type: 'accounts',
        operation: 'update',
        payload: {'id': '1', 'name': 'Second'},
      );

      final operations = await queue.all();
      expect(operations, hasLength(1));
      expect(operations.single.payload['name'], 'Second');
      expect(operations.single.operation, 'update');
    });

    test('delete followed by create replaces with create', () async {
      await queue.enqueue(
        id: 'op-1',
        type: 'accounts',
        operation: 'delete',
        payload: {'id': '1'},
      );
      await queue.enqueue(
        id: 'op-2',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1', 'name': 'New'},
      );

      final operations = await queue.all();
      expect(operations, hasLength(1));
      expect(operations.single.operation, 'create');
    });

    test('operations for different entity IDs are independent', () async {
      await queue.enqueue(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1', 'name': 'Account A'},
      );
      await queue.enqueue(
        id: 'op-2',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '2', 'name': 'Account B'},
      );

      final operations = await queue.all();
      expect(operations, hasLength(2));
    });

    test('operations for different types are independent', () async {
      await queue.enqueue(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1'},
      );
      await queue.enqueue(
        id: 'op-2',
        type: 'categories',
        operation: 'create',
        payload: {'id': '1'},
      );

      final operations = await queue.all();
      expect(operations, hasLength(2));
    });

    test('entities without ids remain independent because they cannot be safely coalesced', () async {
      await queue.enqueue(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'name': 'Account'},
      );
      await queue.enqueue(
        id: 'op-2',
        type: 'accounts',
        operation: 'update',
        payload: {'name': 'Updated'},
      );

      // An empty id is not a stable identity; never merge unrelated operations.
      final operations = await queue.all();
      expect(operations, hasLength(2));
      expect(operations.map((operation) => operation.payload['name']), ['Account', 'Updated']);
    });

    test('forType filters by type', () async {
      await queue.enqueue(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1'},
      );
      await queue.enqueue(
        id: 'op-2',
        type: 'categories',
        operation: 'create',
        payload: {'id': '2'},
      );

      final accounts = await queue.forType('accounts');
      expect(accounts, hasLength(1));
      expect(accounts.first.type, 'accounts');
    });

    test('forType readyOnly filters correctly', () async {
      await queue.enqueue(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1'},
      );

      // Mark it as failed (adds backoff delay)
      await queue.markFailed('op-1');

      final ready = await queue.forType('accounts', readyOnly: true);
      expect(ready, isEmpty);

      final all = await queue.forType('accounts', readyOnly: false);
      expect(all, hasLength(1));
    });
  });

  group('SyncQueue markFailed backoff', () {
    test('exponential backoff grows with attempts', () async {
      await queue.enqueue(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1'},
      );

      await queue.markFailed('op-1');
      var ops = await queue.all();
      expect(ops.first.attempts, 1);

      await queue.markFailed('op-1');
      ops = await queue.all();
      expect(ops.first.attempts, 2);
    });

    test('markFailed on nonexistent id is a no-op', () async {
      await queue.markFailed('nonexistent');
      final operations = await queue.all();
      expect(operations, isEmpty);
    });

    test('remove clears specific operation', () async {
      await queue.enqueue(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1'},
      );
      await queue.enqueue(
        id: 'op-2',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '2'},
      );

      await queue.remove('op-1');
      final operations = await queue.all();
      expect(operations, hasLength(1));
      expect(operations.first.id, 'op-2');
    });

    test('removeWhere clears matching operations', () async {
      await queue.enqueue(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1'},
      );
      await queue.enqueue(
        id: 'op-2',
        type: 'categories',
        operation: 'create',
        payload: {'id': '2'},
      );

      await queue.removeWhere((op) => op.type == 'accounts');
      final operations = await queue.all();
      expect(operations, hasLength(1));
      expect(operations.first.type, 'categories');
    });

    test('clear empties the entire queue', () async {
      await queue.enqueue(
        id: 'op-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': '1'},
      );
      await queue.enqueue(
        id: 'op-2',
        type: 'categories',
        operation: 'create',
        payload: {'id': '2'},
      );

      await queue.clear();
      final operations = await queue.all();
      expect(operations, isEmpty);
    });
  });
}
