import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SyncManager manager;
  late SyncQueue queue;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    manager = SyncManager.instance;
    queue = SyncQueue.instance;
    await manager.resetForTest();
    await queue.clear();

    // Keep singleton handlers and stuck state isolated between tests.
    manager.registerHandler('__test_reset__', (op) async {});
    await manager.flush();
  });

  tearDown(() async {
    await manager.resetForTest();
  });

  test('flush is a no-op when no handler is registered for a pending type', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': '1'},
    );

    // No handler registered for 'accounts' in this manager instance yet.
    await manager.flush();

    final remaining = await queue.all();
    expect(remaining, hasLength(1), reason: 'operation must stay queued');
  });

  test('successful handler removes the operation from the queue', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': '1'},
    );

    manager.registerHandler('accounts', (op) async {});
    await manager.flush();

    final remaining = await queue.all();
    expect(remaining, isEmpty);
  });

  test('accounts operations are replayed before categories', () async {
    await queue.enqueue(
      id: 'categories:create:1',
      type: 'categories',
      operation: 'create',
      payload: {'id': 'cat-1'},
    );
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'acc-1'},
    );

    final callOrder = <String>[];
    manager.registerHandler('accounts', (op) async {
      callOrder.add('accounts');
    });
    manager.registerHandler('categories', (op) async {
      callOrder.add('categories');
    });

    await manager.flush();

    expect(callOrder, ['accounts', 'categories']);
  });

  test('a failing operation blocks the ones behind it but not before it', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'acc-1'},
    );
    await queue.enqueue(
      id: 'categories:create:1',
      type: 'categories',
      operation: 'create',
      payload: {'id': 'cat-1'},
    );

    var categoriesCalled = false;
    manager.registerHandler('accounts', (op) async {
      throw Exception('network error');
    });
    manager.registerHandler('categories', (op) async {
      categoriesCalled = true;
    });

    await manager.flush();

    expect(categoriesCalled, isFalse);
    final remaining = await queue.all();
    expect(remaining, hasLength(2), reason: 'nothing is dropped on failure');
  });

  test('an operation is not marked stuck before reaching the attempt threshold', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'acc-1'},
    );
    manager.registerHandler('accounts', (op) async {
      throw Exception('network error');
    });

    // One failed attempt only — backoff also means it won't be "ready"
    // again immediately, so a single flush is enough to observe the state.
    await manager.flush();

    expect(manager.hasStuckOperations, isFalse);
    expect(manager.stuckOperationsCount, 0);
  });

  test('an operation becomes stuck once it reaches the attempt threshold', () async {
    // Directly simulate an operation that has already failed
    // SyncManager.stuckAfterAttempts times, since the real backoff delay
    // would make a same-test retry loop impractically slow.
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'acc-1'},
    );
    for (var i = 0; i < SyncManager.stuckAfterAttempts; i++) {
      await queue.markFailed('accounts:create:1');
    }

    manager.registerHandler('categories', (op) async {});
    // Trigger a flush so SyncManager recomputes its stuck state from the
    // queue; the accounts operation itself is not ready yet (backoff), so
    // it won't be replayed here — only the stuck-state refresh matters.
    await manager.flush();

    expect(manager.hasStuckOperations, isTrue);
    expect(manager.stuckOperationsCount, 1);
  });

  test('notifies listeners when the stuck state changes', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'acc-1'},
    );
    for (var i = 0; i < SyncManager.stuckAfterAttempts; i++) {
      await queue.markFailed('accounts:create:1');
    }

    var notified = false;
    manager.addListener(() => notified = true);
    manager.registerHandler('categories', (op) async {});
    await manager.flush();

    expect(notified, isTrue);
  });
}
