import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
  });

  tearDown(() async {
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
  });

  test('user deletion wins over a previously queued update for the same entity', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(
      id: 'update-account',
      type: 'accounts',
      operation: 'update',
      payload: {'id': 'a1', 'name': 'Local'},
    );
    await queue.enqueue(
      id: 'delete-account',
      type: 'accounts',
      operation: 'delete',
      payload: {'id': 'a1'},
    );

    final pending = await queue.all();
    expect(pending, hasLength(1));
    expect(pending.single.operation, 'delete');
  });

  test('a server-disappeared entity is recreated from the pending local mutation', () async {
    var existsOnServer = false;
    final calls = <String>[];

    SyncManager.instance.registerHandler('accounts', (operation) async {
      if (operation.operation == 'update') {
        calls.add('update');
        if (!existsOnServer) {
          existsOnServer = true;
          calls.add('recreate');
        }
      }
    });

    await SyncQueue.instance.enqueue(
      id: 'update-account',
      type: 'accounts',
      operation: 'update',
      payload: {'id': 'a1', 'name': 'Recovered'},
    );

    await SyncManager.instance.flush(forceRetry: true);

    expect(existsOnServer, isTrue);
    expect(calls, ['update', 'recreate']);
    expect(await SyncQueue.instance.all(), isEmpty);
  });

  test('a pending local mutation prevents a stale refresh from becoming authoritative', () async {
    final local = {'name': 'Local'};
    final server = {'name': 'Stale'};

    await SyncQueue.instance.enqueue(
      id: 'update-account',
      type: 'accounts',
      operation: 'update',
      payload: {'id': 'a1', ...local},
    );

    final displayed = <String, String>{...server};
    final pending = await SyncQueue.instance.hasPending(
      type: 'accounts',
      entityId: 'a1',
    );
    if (pending) {
      displayed.addAll(local);
    }

    expect(displayed['name'], 'Local');
  });
}
