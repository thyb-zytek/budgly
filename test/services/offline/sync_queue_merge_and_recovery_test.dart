import 'dart:convert';

import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncQueue queue;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    queue = SyncQueue();
  });

  group('payload merging', () {
    test('partial profile patches do not overwrite each other', () async {
      // Offline: onboarding completed, then the theme is changed.
      await queue.enqueue(
        id: 'profile:update:u1',
        type: 'user_profiles',
        operation: 'update',
        payload: {'id': 'u1', 'onboarding_completed': true},
      );
      await queue.enqueue(
        id: 'profile:update:u1',
        type: 'user_profiles',
        operation: 'update',
        payload: {'id': 'u1', 'theme_mode': 'dark'},
      );

      final operations = await queue.all();
      expect(operations, hasLength(1));
      expect(operations.single.payload, {
        'id': 'u1',
        'onboarding_completed': true,
        'theme_mode': 'dark',
      });
    });

    test('a later value wins for the same key', () async {
      await queue.enqueue(
        id: 'a',
        type: 'user_profiles',
        operation: 'update',
        payload: {'id': 'u1', 'currency': 'EUR'},
      );
      await queue.enqueue(
        id: 'b',
        type: 'user_profiles',
        operation: 'update',
        payload: {'id': 'u1', 'currency': 'USD'},
      );

      expect((await queue.all()).single.payload['currency'], 'USD');
    });

    test('create followed by update keeps side-channel keys', () async {
      await queue.enqueue(
        id: 'account:a1',
        type: 'accounts',
        operation: 'create',
        payload: {
          'id': 'a1',
          'name': 'Main',
          '_local_picture_name': '123_avatar.png',
        },
      );
      await queue.enqueue(
        id: 'account:update:a1',
        type: 'accounts',
        operation: 'update',
        payload: {'id': 'a1', 'name': 'Renamed'},
      );

      final operation = (await queue.all()).single;
      expect(operation.operation, 'create');
      expect(operation.id, 'account:a1');
      expect(operation.payload['name'], 'Renamed');
      expect(operation.payload['_local_picture_name'], '123_avatar.png');
    });

    test(
      'an update after a delete does not resurrect the deleted payload',
      () async {
        await queue.enqueue(
          id: 'del',
          type: 'accounts',
          operation: 'delete',
          payload: {'id': 'a1', 'stale': true},
        );
        await queue.enqueue(
          id: 'upd',
          type: 'accounts',
          operation: 'update',
          payload: {'id': 'a1', 'name': 'Back'},
        );

        final operation = (await queue.all()).single;
        expect(operation.operation, 'update');
        expect(operation.payload.containsKey('stale'), isFalse);
      },
    );
  });

  group('corruption recovery', () {
    test(
      'an unreadable blob is quarantined instead of silently overwritten',
      () async {
        SharedPreferences.setMockInitialValues({
          'offline.pending_sync.v2': '{not json',
        });

        expect(await queue.all(), isEmpty);

        final prefs = await SharedPreferences.getInstance();
        final quarantined = prefs
            .getKeys()
            .where((key) => key.startsWith('offline.pending_sync.v2.corrupt.'))
            .toList();
        expect(quarantined, hasLength(1));
        expect(prefs.getString(quarantined.single), '{not json');

        // The queue is usable again and does not re-quarantine on every read.
        await queue.all();
        expect(
          prefs.getKeys().where(
            (key) => key.startsWith('offline.pending_sync.v2.corrupt.'),
          ),
          hasLength(1),
        );
      },
    );

    test(
      'one unreadable entry does not discard the rest of the queue',
      () async {
        SharedPreferences.setMockInitialValues({
          'offline.pending_sync.v2': jsonEncode([
            {
              'id': 'good',
              'type': 'accounts',
              'operation': 'update',
              'payload': {'id': 'a1'},
            },
            {'id': 'bad-without-payload', 'type': 'accounts'},
          ]),
        });

        final operations = await queue.all();
        expect(operations.map((operation) => operation.id), ['good']);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().where(
            (key) => key.startsWith('offline.pending_sync.v2.corrupt.'),
          ),
          hasLength(1),
        );
      },
    );
  });

  group('permanent failures', () {
    test('are flagged, kept and never scheduled for a backoff retry', () async {
      await queue.enqueue(
        id: 'op',
        type: 'categories',
        operation: 'create',
        payload: {'id': 'c1'},
      );

      await queue.applyBatch(permanentFailures: {'op': 'violates foreign key'});

      final operation = (await queue.all()).single;
      expect(operation.permanent, isTrue);
      expect(operation.isReady, isFalse);
      expect(operation.attempts, 1);
      expect(operation.nextAttemptAt, isNull);
      expect(operation.lastError, 'violates foreign key');
      expect(await queue.all(readyOnly: true), isEmpty);
    });

    test('the flag survives serialization', () async {
      await queue.enqueue(
        id: 'op',
        type: 'categories',
        operation: 'create',
        payload: {'id': 'c1'},
      );
      await queue.applyBatch(permanentFailures: {'op': 'boom'});

      final restored = (await SyncQueue().all()).single;
      expect(restored.permanent, isTrue);
      expect(restored.lastError, 'boom');
    });

    test(
      'editing the entity again gives the operation a fresh chance',
      () async {
        await queue.enqueue(
          id: 'op',
          type: 'categories',
          operation: 'update',
          payload: {'id': 'c1', 'name': 'A'},
        );
        await queue.applyBatch(permanentFailures: {'op': 'boom'});

        await queue.enqueue(
          id: 'op2',
          type: 'categories',
          operation: 'update',
          payload: {'id': 'c1', 'name': 'B'},
        );

        final operation = (await queue.all()).single;
        expect(operation.permanent, isFalse);
        expect(operation.isReady, isTrue);
        expect(operation.payload['name'], 'B');
      },
    );
  });

  group('ownership', () {
    test(
      'allForOwner only returns the operations captured by that owner',
      () async {
        var user = 'user-a';
        final owned = SyncQueue(ownerUserIdProvider: () => user);
        await owned.enqueue(
          id: 'a',
          type: 'accounts',
          operation: 'create',
          payload: {'id': 'a1'},
        );
        user = 'user-b';
        await owned.enqueue(
          id: 'b',
          type: 'accounts',
          operation: 'create',
          payload: {'id': 'b1'},
        );

        expect((await owned.allForOwner('user-a')).map((o) => o.id), ['a']);
        expect((await owned.allForOwner('user-b')).map((o) => o.id), ['b']);
      },
    );
  });
}
