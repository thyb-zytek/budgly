import 'dart:async';

import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncQueue queue;
  late SyncManager manager;

  Future<void> enqueueAccount(String id) => queue.enqueue(
    id: 'account:$id',
    type: 'accounts',
    operation: 'create',
    payload: {'id': id},
  );

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

  test(
    'an operation enqueued during a running pass is replayed by a trailing pass',
    () async {
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final replayed = <String>[];

      manager.registerHandler('accounts', (operation) async {
        replayed.add(operation.entityId);
        if (operation.entityId == 'a1') {
          firstStarted.complete();
          await releaseFirst.future;
        }
      });

      await enqueueAccount('a1');
      final first = manager.flush();
      await firstStarted.future;

      // The running pass already read the queue: a2 is invisible to it.
      await enqueueAccount('a2');
      final second = manager.flush();

      releaseFirst.complete();
      await Future.wait([first, second]);

      expect(replayed, ['a1', 'a2']);
      expect(await queue.all(), isEmpty);
    },
  );

  test(
    'concurrent forced flushes never run two passes at the same time',
    () async {
      var active = 0;
      var maxActive = 0;
      var calls = 0;

      manager.registerHandler('accounts', (operation) async {
        calls++;
        active++;
        if (active > maxActive) maxActive = active;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        active--;
        throw StateError('offline');
      });

      await enqueueAccount('a1');
      final running = manager.flush();
      final retryA = manager.flush(forceRetry: true);
      final retryB = manager.flush(forceRetry: true);
      await Future.wait([running, retryA, retryB]);

      expect(maxActive, 1);
      // One normal pass plus a single shared trailing forced pass.
      expect(calls, 2);
    },
  );

  test('waitForIdle only completes once trailing passes are done', () async {
    final replayed = <String>[];
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();

    manager.registerHandler('accounts', (operation) async {
      replayed.add(operation.entityId);
      if (operation.entityId == 'a1') {
        firstStarted.complete();
        await releaseFirst.future;
      }
    });

    await enqueueAccount('a1');
    unawaited(manager.flush());
    await firstStarted.future;
    await enqueueAccount('a2');
    unawaited(manager.flush());

    final idle = manager.waitForIdle();
    releaseFirst.complete();
    await idle;

    expect(replayed, ['a1', 'a2']);
  });

  group('permanent failures', () {
    test(
      'are surfaced immediately and not replayed by background triggers',
      () async {
        var calls = 0;
        manager.registerHandler('accounts', (operation) async {
          calls++;
          throw const FormatException('rejected');
        });

        await enqueueAccount('a1');
        await manager.flush();

        expect(calls, 1);
        expect(manager.hasStuckOperations, isTrue);
        expect(manager.stuckOperationsCount, 1);
        expect((await queue.all()).single.permanent, isTrue);

        // Resume / periodic triggers are forced but must skip permanent ops.
        await manager.flush(forceRetry: true);
        expect(calls, 1);
      },
    );

    test(
      'an explicit user retry replays them and clears the operation on success',
      () async {
        var shouldFail = true;
        var calls = 0;
        manager.registerHandler('accounts', (operation) async {
          calls++;
          if (shouldFail) throw const FormatException('rejected');
        });

        await enqueueAccount('a1');
        await manager.flush();
        expect(manager.hasStuckOperations, isTrue);

        shouldFail = false;
        await manager.flush(forceRetry: true, retryPermanent: true);

        expect(calls, 2);
        expect(await queue.all(), isEmpty);
        expect(manager.hasStuckOperations, isFalse);
      },
    );

    test('a permanent parent keeps blocking its dependents', () async {
      final replayed = <String>[];
      manager.registerHandler('accounts', (operation) async {
        replayed.add('account');
        throw const FormatException('rejected');
      });
      manager.registerHandler('categories', (operation) async {
        replayed.add('category');
      });

      await enqueueAccount('a1');
      await queue.enqueue(
        id: 'category:c1',
        type: 'categories',
        operation: 'create',
        payload: {'id': 'c1', 'account_id': 'a1'},
      );

      await manager.flush();
      await manager.flush(forceRetry: true);

      expect(replayed, ['account']);
      expect(await queue.all(), hasLength(2));
    });
  });

  test(
    'stuck state only counts operations owned by the current user',
    () async {
      final owned = SyncQueue(ownerUserIdProvider: () => 'user-b');
      await owned.enqueue(
        id: 'other',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'x1'},
      );
      await owned.applyBatch(permanentFailures: {'other': 'rejected'});

      final scoped = SyncManager(
        queue: owned,
        analytics: AnalyticsService(),
        ownerUserIdProvider: () => 'user-a',
      );
      scoped.registerHandler('accounts', (operation) async {});
      addTearDown(scoped.resetForTest);

      await scoped.flush(forceRetry: true, retryPermanent: true);

      expect(scoped.hasStuckOperations, isFalse);
      // The other user's operation is neither replayed nor dropped.
      expect(await owned.allForOwner('user-b'), hasLength(1));
    },
  );

  test('a backed-off operation is retried when its backoff expires', () async {
    var calls = 0;
    manager.registerHandler('accounts', (operation) async {
      calls++;
      if (calls == 1) throw StateError('offline');
    });

    await enqueueAccount('a1');
    manager.start();

    // First failure schedules a ~2 s backoff; the manager must wake itself.
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (DateTime.now().isBefore(deadline) &&
        (await queue.all()).isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    expect(calls, 2);
    expect(await queue.all(), isEmpty);
  });
}
