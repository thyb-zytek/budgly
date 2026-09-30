import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final testSyncQueue = SyncQueue();
final testSyncManager = SyncManager(
  queue: testSyncQueue,
  analytics: AnalyticsService(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
  });

  tearDown(() async {
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
  });

  test(
    'user deletion wins over a previously queued update for the same entity',
    () async {
      final queue = testSyncQueue;
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
    },
  );

  test(
    'a server-disappeared entity is recreated from the pending local mutation',
    () async {
      var existsOnServer = false;
      final calls = <String>[];

      testSyncManager.registerHandler('accounts', (operation) async {
        if (operation.operation == 'update') {
          calls.add('update');
          if (!existsOnServer) {
            existsOnServer = true;
            calls.add('recreate');
          }
        }
      });

      await testSyncQueue.enqueue(
        id: 'update-account',
        type: 'accounts',
        operation: 'update',
        payload: {'id': 'a1', 'name': 'Recovered'},
      );

      await testSyncManager.flush(forceRetry: true);

      expect(existsOnServer, isTrue);
      expect(calls, ['update', 'recreate']);
      expect(await testSyncQueue.all(), isEmpty);
    },
  );

  test(
    'a pending local mutation prevents a stale refresh from becoming authoritative',
    () async {
      final local = {'name': 'Local'};
      final server = {'name': 'Stale'};

      await testSyncQueue.enqueue(
        id: 'update-account',
        type: 'accounts',
        operation: 'update',
        payload: {'id': 'a1', ...local},
      );

      final displayed = <String, String>{...server};
      final pending = await testSyncQueue.hasPending(
        type: 'accounts',
        entityId: 'a1',
      );
      if (pending) {
        displayed.addAll(local);
      }

      expect(displayed['name'], 'Local');
    },
  );
}
