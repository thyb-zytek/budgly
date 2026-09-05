import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SyncQueue queue;

  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  setUp(() async {
    queue = SyncQueue.instance;
    await queue.clear();
  });

  test('offline create -> update -> delete collapses to no server work', () async {
    await queue.enqueue(
      id: 'create-e1',
      type: 'expenses',
      operation: 'create',
      payload: {'id': 'e1', 'amount': 10},
    );
    await queue.enqueue(
      id: 'update-e1',
      type: 'expenses',
      operation: 'update',
      payload: {'id': 'e1', 'amount': 20},
    );
    await queue.enqueue(
      id: 'delete-e1',
      type: 'expenses',
      operation: 'delete',
      payload: {'id': 'e1'},
    );

    expect(await queue.all(), isEmpty);
  });

  test('multiple offline updates retain only the latest payload', () async {
    for (var i = 1; i <= 10; i++) {
      await queue.enqueue(
        id: 'update-$i',
        type: 'expenses',
        operation: 'update',
        payload: {'id': 'e1', 'amount': i * 10},
      );
    }

    final ops = await queue.all();
    expect(ops, hasLength(1));
    expect(ops.single.payload['amount'], 100);
  });

  test('unrelated entities keep their relative operations', () async {
    await queue.enqueue(
      id: 'e1-create', type: 'expenses', operation: 'create', payload: {'id': 'e1'},
    );
    await queue.enqueue(
      id: 'e2-update', type: 'expenses', operation: 'update', payload: {'id': 'e2', 'amount': 2},
    );
    await queue.enqueue(
      id: 'e1-update', type: 'expenses', operation: 'update', payload: {'id': 'e1', 'amount': 3},
    );

    final ops = await queue.all();
    expect(ops.map((e) => e.entityId), ['e2', 'e1']);
    expect(ops.last.operation, 'create');
    expect(ops.last.payload['amount'], 3);
  });

  test('queue survives a fresh SharedPreferences read', () async {
    await queue.enqueue(
      id: 'persisted',
      type: 'categories',
      operation: 'update',
      payload: {'id': 'c1', 'name': 'Offline'},
    );

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline.pending_sync.v2');
    expect(raw, isNotNull);
    expect(raw, contains('persisted'));
    expect(raw, contains('Offline'));
  });

  test('failure backoff survives a queue read and remains not ready', () async {
    await queue.enqueue(
      id: 'retry',
      type: 'expenses',
      operation: 'update',
      payload: {'id': 'e1'},
    );
    await queue.markFailed('retry');

    final restored = (await queue.all()).single;
    expect(restored.attempts, 1);
    expect(restored.isReady, isFalse);
  });
}
