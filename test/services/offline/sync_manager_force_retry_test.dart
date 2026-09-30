import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final queue = SyncQueue();
  final manager = SyncManager(queue: queue, analytics: AnalyticsService());

  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  setUp(() async {
    await queue.clear();
    await manager.resetForTest();
    await manager.flush();
  });
  tearDown(() async {
    await queue.clear();
    await manager.resetForTest();
    await manager.flush();
  });

  test('forceRetry executes a queued operation still inside backoff', () async {
    await queue.enqueue(
      id: 'force-retry-1',
      type: 'force-retry-test',
      operation: 'update',
      payload: {'id': 'e1'},
    );
    await queue.markFailed('force-retry-1');

    var called = 0;
    manager.registerHandler('force-retry-test', (_) async {
      called++;
    });

    await manager.flush();
    expect(called, 0);
    expect(await queue.all(), hasLength(1));

    await manager.flush(forceRetry: true);

    expect(called, 1);
    expect(await queue.all(), isEmpty);
  });

  test(
    'forceRetry preserves account-before-category dependency order',
    () async {
      final calls = <String>[];
      await queue.enqueue(
        id: 'category-1',
        type: 'categories',
        operation: 'create',
        payload: {'id': 'c1', 'account_id': 'a1'},
      );
      await queue.enqueue(
        id: 'account-1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'a1'},
      );
      await queue.markFailed('account-1');

      manager.registerHandler('accounts', (_) async => calls.add('account'));
      manager.registerHandler('categories', (_) async => calls.add('category'));

      await manager.flush(forceRetry: true);

      expect(calls, ['account', 'category']);
      expect(await queue.all(), isEmpty);
    },
  );

  test('resume replays an operation still inside backoff', () async {
    await queue.enqueue(
      id: 'resume-1',
      type: 'resume-test',
      operation: 'update',
      payload: {'id': 'e1'},
    );
    await queue.markFailed('resume-1');

    var called = 0;
    manager.registerHandler('resume-test', (_) async {
      called++;
    });

    // A regular flush skips the backed-off operation.
    await manager.flush();
    expect(called, 0);
    expect(await queue.all(), hasLength(1));

    // Returning to the app is the most common moment where connectivity is
    // back: the forced lifecycle flush must replay it without waiting out the
    // backoff window.
    manager.start();
    manager.didChangeAppLifecycleState(AppLifecycleState.resumed);

    for (var i = 0; i < 50; i++) {
      await manager.waitForIdle();
      if ((await queue.all()).isEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(called, 1);
    expect(await queue.all(), isEmpty);
  });
}
