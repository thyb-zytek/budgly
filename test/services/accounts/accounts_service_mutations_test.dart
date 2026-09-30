import 'dart:io';

import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers.dart';

class _FakeAccountSupabase extends AccountSupabase {
  _FakeAccountSupabase(this.remote);

  final List<Account> remote;

  @override
  Future<List<Account>> listByUserId(String userId) async => remote;
}

/// A queue whose storage is unavailable.
class _BrokenQueue extends SyncQueue {
  @override
  Future<void> enqueue({
    required String id,
    required String type,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    throw StateError('queue storage unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
  late LocalCache cache;

  Account account(String id, {String? picture}) =>
      Account(id: id, name: id, userId: 'u1', picture: picture);

  AccountsService service({
    List<Account> remote = const [],
    SyncQueue? queue,
  }) => AccountsService(
    accountSupabase: _FakeAccountSupabase(remote),
    auth: auth,
    analytics: AnalyticsService(),
    syncManager: testSyncManager,
    syncQueue: queue ?? testSyncQueue,
    localCache: cache,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache();
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
  });

  tearDown(() async {
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
  });

  test(
    'an account deleted offline is not resurrected by a revalidation',
    () async {
      final svc = service(remote: [account('a1'), account('a2')]);
      await svc.loadAccounts();

      await svc.deleteAccount('a1');
      svc.invalidateCache();
      final reloaded = await svc.loadAccounts(forceRefresh: true);

      expect(reloaded.map((a) => a.id), ['a2']);
      expect((await cache.loadAccounts('u1'))!.map((a) => a.id), ['a2']);
    },
  );

  test(
    'an account created offline survives a revalidation that does not know it',
    () async {
      final svc = service(remote: [account('remote1')]);
      await svc.loadAccounts();

      final created = await svc.createAccount(const Account(name: 'Offline'));
      svc.invalidateCache();
      final reloaded = await svc.loadAccounts(forceRefresh: true);

      expect(reloaded.map((a) => a.id), containsAll(['remote1', created.id]));
    },
  );

  test('a queue failure is reported and leaves the cache untouched', () async {
    final svc = service(remote: [account('a1')], queue: _BrokenQueue());
    await svc.loadAccounts();

    await expectLater(
      svc.createAccount(const Account(name: 'Never persisted')),
      throwsStateError,
    );
    await expectLater(svc.updateAccount(account('a1')), throwsStateError);
    await expectLater(svc.deleteAccount('a1'), throwsStateError);

    expect((await cache.loadAccounts('u1'))!.map((a) => a.id), ['a1']);
  });

  test(
    'the durable queue entry exists as soon as createAccount returns',
    () async {
      final svc = service();
      final created = await svc.createAccount(const Account(name: 'Main'));

      final operations = await testSyncQueue.forType('accounts');
      expect(operations.single.operation, 'create');
      expect(operations.single.entityId, created.id);
    },
  );

  test('editing an account does not drop its queued picture upload', () async {
    final svc = service(remote: [account('a1', picture: '123_avatar.png')]);
    await svc.loadAccounts();
    final file = File('${Directory.systemTemp.path}/123_avatar.png');

    await svc.queuePictureUpload(
      account('a1', picture: '123_avatar.png'),
      file,
    );
    await svc.updateAccount(
      const Account(
        id: 'a1',
        userId: 'u1',
        name: 'Renamed',
        picture: '123_avatar.png',
      ),
    );

    final operation = (await testSyncQueue.forType('accounts')).single;
    expect(operation.payload['name'], 'Renamed');
    expect(operation.payload['_local_picture_name'], '123_avatar.png');
    expect(
      operation.payload.containsKey('_local_picture_path'),
      isFalse,
      reason: 'an absolute path breaks when the iOS container path changes',
    );
  });

  test(
    'concurrent creations never overwrite each other in the cache',
    () async {
      final svc = service();
      await Future.wait([
        for (var i = 0; i < 10; i++) svc.createAccount(Account(name: 'A$i')),
      ]);

      expect(await cache.loadAccounts('u1'), hasLength(10));
      expect(await testSyncQueue.forType('accounts'), hasLength(10));
    },
  );
}
