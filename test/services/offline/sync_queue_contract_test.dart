import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncQueue.instance.clear();
  });

  tearDown(() => SyncQueue.instance.clear());

  test('distinct entities preserve arrival order', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(id: 'a', type: 'expenses', operation: 'update', payload: {'id': 'a'});
    await queue.enqueue(id: 'b', type: 'expenses', operation: 'update', payload: {'id': 'b'});
    await queue.enqueue(id: 'c', type: 'expenses', operation: 'update', payload: {'id': 'c'});

    expect((await queue.all()).map((operation) => operation.entityId), ['a', 'b', 'c']);
  });

  test('create followed by update keeps the create identity and latest payload', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(id: 'create', type: 'expenses', operation: 'create', payload: {'id': 'e1', 'amount': 10});
    await queue.enqueue(id: 'update', type: 'expenses', operation: 'update', payload: {'id': 'e1', 'amount': 25});

    final operation = (await queue.all()).single;
    expect(operation.operation, 'create');
    expect(operation.id, 'create');
    expect(operation.payload['amount'], 25);
  });

  test('delete followed by update keeps the latest update as the local intent', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(
      id: 'delete',
      type: 'expenses',
      operation: 'delete',
      payload: {'id': 'e1'},
    );
    await queue.enqueue(
      id: 'update',
      type: 'expenses',
      operation: 'update',
      payload: {'id': 'e1', 'amount': 75},
    );

    final operation = (await queue.all()).single;
    expect(operation.operation, 'update');
    expect(operation.payload['amount'], 75);
  });

  test('create followed by delete cancels the pending server work', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(id: 'create', type: 'expenses', operation: 'create', payload: {'id': 'e1'});
    await queue.enqueue(id: 'delete', type: 'expenses', operation: 'delete', payload: {'id': 'e1'});

    expect(await queue.all(), isEmpty);
  });

  test('persisted queue state is recoverable after a fresh read', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'offline.pending_sync.v2',
      '[{"id":"restart-1","type":"expenses","operation":"update",'
      '"payload":{"id":"e1","amount":99},"attempts":2,'
      '"next_attempt_at":null}]',
    );

    final recovered = await SyncQueue.instance.all();
    expect(recovered.single.id, 'restart-1');
    expect(recovered.single.attempts, 2);
    expect(recovered.single.payload['amount'], 99);
  });

  test('failure attempts and backoff are persisted', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(id: 'retry', type: 'expenses', operation: 'update', payload: {'id': 'e1'});

    await queue.markFailed('retry');
    final first = (await queue.all()).single;
    expect(first.attempts, 1);
    expect(first.nextAttemptAt, isNotNull);
    expect(first.isReady, isFalse);

    await queue.markFailed('retry');
    final second = (await queue.all()).single;
    expect(second.attempts, 2);
    expect(second.nextAttemptAt!.isAfter(first.nextAttemptAt!), isTrue);
  });
}
