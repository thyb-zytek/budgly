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
    await queue.clear();

    manager.registerHandler('__test_reset__', (op) async {});
    await manager.flush();
  });

  tearDown(() async {
    await manager.stop();
  });

  test('flush processes user_profiles between accounts and categories', () async {
    await queue.enqueue(
      id: 'user_profiles:create:1',
      type: 'user_profiles',
      operation: 'create',
      payload: {'id': 'u1'},
    );
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'a1'},
    );
    await queue.enqueue(
      id: 'categories:create:1',
      type: 'categories',
      operation: 'create',
      payload: {'id': 'c1'},
    );

    final callOrder = <String>[];
    manager.registerHandler('accounts', (op) async {
      callOrder.add('accounts');
    });
    manager.registerHandler('user_profiles', (op) async {
      callOrder.add('user_profiles');
    });
    manager.registerHandler('categories', (op) async {
      callOrder.add('categories');
    });

    await manager.flush();

    expect(callOrder, ['accounts', 'user_profiles', 'categories']);
  });

  test('categories are blocked when account operation is pending (not ready)', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'a1'},
    );
    await queue.enqueue(
      id: 'categories:create:1',
      type: 'categories',
      operation: 'create',
      payload: {'id': 'c1'},
    );

    // Mark accounts as failed so it has a backoff delay (not ready)
    await queue.markFailed('accounts:create:1');

    var categoriesCalled = false;
    manager.registerHandler('accounts', (op) async {});
    manager.registerHandler('categories', (op) async {
      categoriesCalled = true;
    });

    await manager.flush();

    expect(categoriesCalled, isFalse);
  });

  test('categories are processed when all account operations are ready', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'a1'},
    );
    await queue.enqueue(
      id: 'categories:create:1',
      type: 'categories',
      operation: 'create',
      payload: {'id': 'c1'},
    );

    var categoriesCalled = false;
    manager.registerHandler('accounts', (op) async {});
    manager.registerHandler('categories', (op) async {
      categoriesCalled = true;
    });

    await manager.flush();

    expect(categoriesCalled, isTrue);
  });

  test('flush is a no-op when already syncing', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'a1'},
    );

    var callCount = 0;
    manager.registerHandler('accounts', (op) async {
      callCount++;
    });

    // Run flush twice concurrently — second should be a no-op
    await Future.wait([manager.flush(), manager.flush()]);

    expect(callCount, 1);
  });

  test('flush is a no-op when queue is empty', () async {
    manager.registerHandler('accounts', (op) async {});
    await manager.flush();
    // Should not throw
  });

  test('multiple stuck operations are counted', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'a1'},
    );
    await queue.enqueue(
      id: 'accounts:create:2',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'a2'},
    );

    for (var i = 0; i < SyncManager.stuckAfterAttempts; i++) {
      await queue.markFailed('accounts:create:1');
      await queue.markFailed('accounts:create:2');
    }

    manager.registerHandler('categories', (op) async {});
    await manager.flush();

    expect(manager.hasStuckOperations, isTrue);
    expect(manager.stuckOperationsCount, 2);
  });

  test('stuck state clears when operations are removed', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'a1'},
    );

    for (var i = 0; i < SyncManager.stuckAfterAttempts; i++) {
      await queue.markFailed('accounts:create:1');
    }

    manager.registerHandler('accounts', (op) async {});
    await manager.flush();
    expect(manager.hasStuckOperations, isTrue);

    await queue.remove('accounts:create:1');
    await manager.flush();
    expect(manager.hasStuckOperations, isFalse);
    expect(manager.stuckOperationsCount, 0);
  });

  test('start is idempotent', () async {
    manager.start();
    manager.start(); // Should not throw or create duplicate timers
    // No explicit assertion needed — just shouldn't throw
  });

  test('stop is idempotent', () async {
    manager.start();
    await manager.stop();
    await manager.stop(); // Should not throw
  });
}
