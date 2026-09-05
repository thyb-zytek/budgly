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

  test('test reset removes handlers and stuck state from the singleton', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(
      id: 'reset-1',
      type: 'reset-test',
      operation: 'update',
      payload: {'id': 'e1'},
    );
    for (var i = 0; i < SyncManager.stuckAfterAttempts; i++) {
      await queue.markFailed('reset-1');
    }

    SyncManager.instance.registerHandler('reset-test', (_) async {});
    await SyncManager.instance.flush();
    expect(SyncManager.instance.hasStuckOperations, isTrue);

    await SyncManager.instance.resetForTest();
    expect(SyncManager.instance.hasStuckOperations, isFalse);
    expect(SyncManager.instance.stuckOperationsCount, 0);

    await SyncManager.instance.flush(forceRetry: true);
    expect(await queue.hasPending(type: 'reset-test'), isTrue);
  });

  test('forceRetry drains a pending operation inside backoff', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(
      id: 'contract-1',
      type: 'contract',
      operation: 'update',
      payload: {'id': 'e1'},
    );
    await queue.markFailed('contract-1');

    var calls = 0;
    SyncManager.instance.registerHandler('contract', (_) async {
      calls++;
    });

    await SyncManager.instance.flush();
    expect(calls, 0);
    expect(await queue.all(), hasLength(1));

    await SyncManager.instance.flush(forceRetry: true);

    expect(calls, 1);
    expect(await queue.all(), isEmpty);
  });

  test('a pending parent blocks dependent expense replay', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(
      id: 'account',
      type: 'accounts',
      operation: 'update',
      payload: {'id': 'a1'},
    );
    await queue.enqueue(
      id: 'expense',
      type: 'expenses',
      operation: 'update',
      payload: {'id': 'e1', 'accountId': 'a1', 'categoryId': 'c1', 'name': 'x', 'amount': 1, 'debitDate': '2026-03-01T00:00:00.000', 'recurrence': 'none', 'recurrenceAnchorDay': 1, 'isDebited': false, 'debitedOccurrences': []},
    );
    await queue.markFailed('account');

    var expenseCalls = 0;
    SyncManager.instance.registerHandler('accounts', (_) async {});
    SyncManager.instance.registerHandler('expenses', (_) async {
      expenseCalls++;
    });

    await SyncManager.instance.flush();

    expect(expenseCalls, 0);
    expect(await queue.hasPending(type: 'expenses', entityId: 'e1'), isTrue);
  });

  test('a failed operation blocks later operations without dropping either', () async {
    final queue = SyncQueue.instance;
    await queue.enqueue(id: 'a', type: 'contract', operation: 'update', payload: {'id': 'a'});
    await queue.enqueue(id: 'b', type: 'contract', operation: 'update', payload: {'id': 'b'});

    final calls = <String>[];
    SyncManager.instance.registerHandler('contract', (operation) async {
      calls.add(operation.entityId);
      if (operation.entityId == 'a') throw StateError('offline');
    });

    await SyncManager.instance.flush();

    expect(calls, ['a']);
    expect((await queue.all()).map((e) => e.entityId), ['a', 'b']);
  });
}
