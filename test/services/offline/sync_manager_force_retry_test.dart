import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  setUp(() async {
    await SyncQueue.instance.clear();
    await SyncManager.instance.resetForTest();
    await SyncManager.instance.flush();
  });
  tearDown(() async {
    await SyncQueue.instance.clear();
    await SyncManager.instance.resetForTest();
    await SyncManager.instance.flush();
  });

  test('forceRetry executes a queued operation still inside backoff', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(
      id: 'force-retry-1',
      type: 'force-retry-test',
      operation: 'update',
      payload: {'id': 'e1'},
    );
    await queue.markFailed('force-retry-1');

    var called = 0;
    SyncManager.instance.registerHandler('force-retry-test', (_) async {
      called++;
    });

    await SyncManager.instance.flush();
    expect(called, 0);
    expect(await queue.all(), hasLength(1));

    await SyncManager.instance.flush(forceRetry: true);

    expect(called, 1);
    expect(await queue.all(), isEmpty);
  });

  test('forceRetry preserves account-before-category dependency order', () async {
    final queue = SyncQueue.instance;
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

    SyncManager.instance.registerHandler('accounts', (_) async => calls.add('account'));
    SyncManager.instance.registerHandler('categories', (_) async => calls.add('category'));

    await SyncManager.instance.flush(forceRetry: true);

    expect(calls, ['account', 'category']);
    expect(await queue.all(), isEmpty);
  });

  test('resume replays an operation still inside backoff', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(
      id: 'resume-1',
      type: 'resume-test',
      operation: 'update',
      payload: {'id': 'e1'},
    );
    await queue.markFailed('resume-1');

    var called = 0;
    SyncManager.instance.registerHandler('resume-test', (_) async {
      called++;
    });

    // A regular flush skips the backed-off operation.
    await SyncManager.instance.flush();
    expect(called, 0);
    expect(await queue.all(), hasLength(1));

    // Returning to the app is the most common moment where connectivity is
    // back: the forced lifecycle flush must replay it without waiting out the
    // backoff window.
    SyncManager.instance.start();
    SyncManager.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);

    for (var i = 0; i < 50; i++) {
      await SyncManager.instance.waitForIdle();
      if ((await queue.all()).isEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(called, 1);
    expect(await queue.all(), isEmpty);
  });
}
