import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for LocalCache's schema versioning (docs/AUDIT_PLAN.md,
/// X5): every cache key embeds a schema version, and an old-scheme entry is
/// invisible to reads (falls back to the server) rather than risking a silent
/// bad decode of stale data.
void main() {
  late LocalCache cache;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache();
  });

  test(
    'an entry written under an old scheme is invisible to the current version',
    () async {
      SharedPreferences.setMockInitialValues({
        // The pre-versioning key shape.
        'offline.accounts.user-1': '[{"id":"a1","name":"Old"}]',
      });

      expect(await cache.loadAccounts('user-1'), isNull);
    },
  );

  test('a freshly saved entry round-trips under the versioned key', () async {
    const account = Account(id: 'a1', userId: 'user-1', name: 'Main');
    await cache.saveAccounts('user-1', [account]);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('offline.v1.accounts.user-1'), isNotNull);
    expect((await cache.loadAccounts('user-1'))!.single.id, 'a1');
  });

  group('purgeObsoleteCacheEntries', () {
    test(
      'removes every pre-versioning LocalCache key, including quarantined blobs',
      () async {
        SharedPreferences.setMockInitialValues({
          'offline.accounts.user-1': 'not-json',
          'offline.accounts.user-1.corrupt': 'not-json',
          'offline.categories.acc-1': '[]',
          'offline.profile.user-1': '{}',
          'undebited.banner.dismissedAt.acc-1':
              '2026-3|2026-03-15T00:00:00.000',
        });

        await cache.purgeObsoleteCacheEntries();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getKeys(), isEmpty);
      },
    );

    test('never touches the current schema version', () async {
      const account = Account(id: 'a1', userId: 'user-1', name: 'Main');
      await cache.saveAccounts('user-1', [account]);

      await cache.purgeObsoleteCacheEntries();

      expect((await cache.loadAccounts('user-1'))!.single.id, 'a1');
    });

    test('never touches an unrelated namespace such as SyncQueue', () async {
      // Regression: a first draft of this method matched any key starting
      // with "offline." and not the current LocalCache namespace, which
      // would also have deleted SyncQueue's durable data.
      SharedPreferences.setMockInitialValues({
        'offline.pending_sync.v2': '[{"id":"op-1"}]',
        'offline.accounts.user-1': 'stale',
      });

      await cache.purgeObsoleteCacheEntries();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('offline.pending_sync.v2'), isNotNull);
      expect(prefs.getString('offline.accounts.user-1'), isNull);
    });

    test(
      'is safe to call repeatedly and is a no-op with nothing obsolete',
      () async {
        await cache.purgeObsoleteCacheEntries();
        await cache.purgeObsoleteCacheEntries();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getKeys(), isEmpty);
      },
    );
  });
}
