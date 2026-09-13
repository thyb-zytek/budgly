import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_manager_provider.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SyncManager manager;
  late SyncQueue queue;
  late ProviderContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // SyncManager only exposes a private constructor: tests share the
    // singleton, like every other test for this service, and rely on
    // `resetForTest()` for isolation (see sync_manager_test.dart).
    manager = SyncManager.instance;
    queue = SyncQueue.instance;
    await manager.resetForTest();
    await queue.clear();
    manager.registerHandler('__test_reset__', (op) async {});
    await manager.flush();

    container = ProviderContainer(
      overrides: [syncManagerProvider.overrideWithValue(manager)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await manager.resetForTest();
  });

  test('syncManagerProvider exposes the given manager', () {
    expect(container.read(syncManagerProvider), same(manager));
  });

  test('initial status mirrors the manager', () {
    final status = container.read(syncStatusProvider);
    expect(status.isSyncing, manager.isSyncing);
    expect(status.hasStuckOperations, manager.hasStuckOperations);
    expect(status.stuckOperationsCount, manager.stuckOperationsCount);
  });

  test('reflects a successful flush cycle', () async {
    container.read(syncStatusProvider); // ensure build() ran

    var notifications = 0;
    container.listen(syncStatusProvider, (previous, next) => notifications++);

    manager.registerHandler('accounts', (op) async {});
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': '1'},
    );
    await manager.flush();

    // A full flush cycle notifies at least once (start and/or completion).
    expect(notifications, greaterThanOrEqualTo(1));
    expect(container.read(syncStatusProvider).isSyncing, isFalse);
  });

  test('SyncStatus== is value-based', () {
    const a = SyncStatus(isSyncing: false, hasStuckOperations: false, stuckOperationsCount: 0);
    const b = SyncStatus(isSyncing: false, hasStuckOperations: false, stuckOperationsCount: 0);
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('disposing the container detaches the listener without error', () async {
    container.read(syncStatusProvider);
    final localContainer = ProviderContainer(
      overrides: [syncManagerProvider.overrideWithValue(manager)],
    );
    localContainer.read(syncStatusProvider);
    localContainer.dispose();

    manager.registerHandler('accounts', (op) async {});
    await queue.enqueue(
      id: 'accounts:create:2',
      type: 'accounts',
      operation: 'create',
      payload: {'id': '2'},
    );

    // Must not throw even though localContainer (and its listener) is gone.
    await manager.flush();
  });
}
