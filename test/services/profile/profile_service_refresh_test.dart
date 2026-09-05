import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
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
    // Keep the shared SyncManager singleton deterministic between tests.
    manager.registerHandler('__test_reset__', (op) async {});
    await manager.flush();
  });

  tearDown(() async {
    await manager.resetForTest();
  });

  test('returns true when online: every pending mutation reaches the server', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'acc-1'},
    );

    // A handler that succeeds mimics reaching the server (online).
    manager.registerHandler('accounts', (op) async {});

    final online = await ProfileService.flushPendingMutations();

    expect(online, isTrue, reason: 'queue must be empty after a successful flush');
    expect(await queue.all(), isEmpty);
  });

  test('returns false when offline: a failing mutation stays queued', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'acc-1'},
    );

    // A handler that throws mimics an unreachable server (offline).
    manager.registerHandler('accounts', (op) async {
      throw Exception('network unreachable');
    });

    final online = await ProfileService.flushPendingMutations();

    expect(online, isFalse, reason: 'a pending mutation remains, device is offline');
    expect(await queue.all(), hasLength(1), reason: 'nothing is dropped on failure');
  });

  test('returns true when there are no pending mutations at all', () async {
    final online = await ProfileService.flushPendingMutations();

    expect(online, isTrue);
  });
}
