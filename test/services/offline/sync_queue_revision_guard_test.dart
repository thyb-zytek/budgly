import 'dart:async';

import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A replay pass reads the queue, then awaits the remote call. A mutation
/// enqueued under the same operation id during that await supersedes the
/// payload being replayed: the pass must not remove (or fail) the newer one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncQueue queue;
  late SyncManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    queue = SyncQueue();
    manager = SyncManager(
      queue: queue,
      analytics: AnalyticsService(),
      isPermanentError: (error) => error is FormatException,
    );
  });

  tearDown(() async {
    await manager.resetForTest();
    await queue.clear();
  });

  Future<void> enqueueUpdate(String id, String name) => queue.enqueue(
    id: 'account:update:$id',
    type: 'accounts',
    operation: 'update',
    payload: {'id': id, 'name': name},
  );

  test('an update enqueued during its own replay is replayed again', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final replayedNames = <String>[];

    manager.registerHandler('accounts', (operation) async {
      replayedNames.add(operation.payload['name'] as String);
      if (replayedNames.length == 1) {
        started.complete();
        await release.future;
      }
    });

    await enqueueUpdate('a1', 'old');
    final first = manager.flush();
    await started.future;

    // Same operation id, newer payload, while "old" is in flight.
    await enqueueUpdate('a1', 'new');
    final second = manager.flush();

    release.complete();
    await Future.wait([first, second]);

    expect(replayedNames, ['old', 'new']);
    expect(await queue.all(), isEmpty);
  });

  test(
    'a successful replay of the old payload does not remove the newer one',
    () async {
      await enqueueUpdate('a1', 'old');
      final replayed = (await queue.all()).single;

      await enqueueUpdate('a1', 'new');
      await queue.applyBatch(
        removeIds: {replayed.id},
        replayedRevisions: {replayed.id: replayed.revision},
      );

      final remaining = await queue.all();
      expect(remaining, hasLength(1));
      expect(remaining.single.payload['name'], 'new');
    },
  );

  test(
    'a failure of the old payload is not recorded against the newer one',
    () async {
      await enqueueUpdate('a1', 'old');
      final replayed = (await queue.all()).single;

      await enqueueUpdate('a1', 'new');
      await queue.applyBatch(
        permanentFailures: {replayed.id: 'rejected'},
        replayedRevisions: {replayed.id: replayed.revision},
      );

      final remaining = (await queue.all()).single;
      expect(remaining.payload['name'], 'new');
      expect(remaining.permanent, isFalse);
    },
  );

  test('without a revision map the previous behavior is kept', () async {
    await enqueueUpdate('a1', 'old');
    final replayed = (await queue.all()).single;

    await queue.applyBatch(removeIds: {replayed.id});

    expect(await queue.all(), isEmpty);
  });

  test('the revision is persisted and survives a reload', () async {
    await enqueueUpdate('a1', 'v1');
    await enqueueUpdate('a1', 'v2');

    final reloaded = SyncQueue();
    final operation = (await reloaded.all()).single;

    expect(operation.payload['name'], 'v2');
    expect(operation.revision, greaterThan(0));
  });

  test('create followed by update coalesces and bumps the revision', () async {
    await queue.enqueue(
      id: 'account:create:a1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'a1', 'name': 'old'},
    );
    final first = (await queue.all()).single;

    await queue.enqueue(
      id: 'account:update:a1',
      type: 'accounts',
      operation: 'update',
      payload: {'id': 'a1', 'name': 'new'},
    );

    final merged = (await queue.all()).single;
    expect(merged.operation, 'create');
    expect(merged.payload['name'], 'new');
    expect(merged.revision, greaterThan(first.revision));
  });
}
