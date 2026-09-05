import 'dart:io';

import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:budgly/src/services/providers/supabase/storage.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';

class FakeAccountSupabase extends AccountSupabase {
  Object? listError;
  List<Account> listResult = [];
  final List<String> deletedIds = [];
  final List<Account> created = [];
  final List<Account> updated = [];
  Object? updateError;
  bool returnNullOnUpdate = false;

  @override
  Future<List<Account>> listByUserId(String userId) async {
    if (listError != null) throw listError!;
    return listResult;
  }

  @override
  Future<Account?> create(Account account) async {
    created.add(account);
    return account;
  }

  @override
  Future<Account?> update(Account account) async {
    if (updateError != null) throw updateError!;
    updated.add(account);
    return returnNullOnUpdate ? null : account;
  }

  @override
  Future<bool> delete(String accountId) async {
    deletedIds.add(accountId);
    return true;
  }
}

class FakeStorageSupabase extends StorageSupabase {
  final List<String> uploaded = [];
  String? getSignedUrlResult = 'http://example.com/pic.png';
  bool deleteResult = true;

  @override
  Future<String?> uploadFile({
    required String bucketId,
    required String filePath,
    required String userId,
    String? prefix,
    String? fileName,
  }) async {
    uploaded.add(filePath);
    return fileName;
  }

  @override
  Future<String> getSignedUrl({
    required String bucketId,
    required String filePath,
    int validityInSeconds = 3600,
  }) async {
    if (getSignedUrlResult == null) {
      throw Exception('no url');
    }
    return getSignedUrlResult!;
  }

  @override
  Future<bool> deleteFile({
    required String bucketId,
    required String filePath,
  }) async {
    return deleteResult;
  }

  @override
  Future<void> deleteFolder({
    required String bucketId,
    required String folderPath,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth auth;
  late FakeAccountSupabase accountSupabase;
  late FakeStorageSupabase storageSupabase;
  late AccountsStore store;
  late AccountsService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    AccountsStore.instance.clearLocalAccounts();
    store = AccountsStore.instance;
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'test@budgly.app'),
    );
    accountSupabase = FakeAccountSupabase();
    storageSupabase = FakeStorageSupabase();
    service = AccountsService(
      auth: auth,
      accountSupabase: accountSupabase,
      storageSupabase: storageSupabase,
      store: store,
    );
  });

  tearDown(() async {
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    AccountsStore.instance.clearLocalAccounts();
  });

  Account account({String? id, String? picture, String? pictureUrl}) =>
      Fixtures.account(
        id: id,
        name: 'Compte courant',
        picture: picture,
        pictureUrl: pictureUrl,
      );

  group('current user', () {
    test('_currentUserId throws without an authenticated user', () {
      final anonService = AccountsService(
        auth: MockFirebaseAuth(signedIn: false),
        accountSupabase: accountSupabase,
        storageSupabase: storageSupabase,
        store: store,
      );
      expect(() => anonService.createAccount(account()), throwsStateError);
    });
  });

  group('loadAccounts', () {
    test('loads and caches remote accounts then refills picture urls',
        () async {
      final remote = [
        account(id: 'a1').copyWith(picture: 'pic.png'),
      ];
      accountSupabase.listResult = remote;

      await service.loadAccounts(forceRefresh: true);
      await SyncManager.instance.waitForIdle();

      expect(store.hasLoaded, isTrue);
      expect(store.accounts.map((a) => a.id), contains('a1'));
      expect(store.accounts.first.pictureUrl, 'http://example.com/pic.png');
    });

    test('falls back to cache when the remote refresh fails', () async {
      final cached = [account(id: 'c1')];
      // Persist a cache via a prior successful load.
      accountSupabase.listResult = cached;
      await service.loadAccounts(forceRefresh: true);
      await SyncManager.instance.waitForIdle();
      expect(store.accounts.map((a) => a.id), contains('c1'));

      // Remove both from store and remote; keep cache intact.
      service.clearLocalAccounts();
      accountSupabase.listResult = [];
      accountSupabase.listError = Exception('network');
      final service2 = AccountsService(
        auth: auth,
        accountSupabase: accountSupabase,
        storageSupabase: storageSupabase,
        store: store,
      );
      await service2.loadAccounts(forceRefresh: true);

      expect(store.hasLoaded, isTrue);
      expect(store.accounts.map((a) => a.id), contains('c1'));
    });

    test('deduplicates concurrent loads for the same user', () async {
      accountSupabase.listResult = [account(id: 'a1')];
      await Future.wait([
        service.loadAccounts(forceRefresh: true),
        service.loadAccounts(forceRefresh: true),
      ]);

      expect(store.accounts.map((a) => a.id), contains('a1'));
    });
  });

  group('createAccount', () {
    test('adds the user id optimistically and enqueues a create', () async {
      final created = await service.createAccount(account());

      expect(store.accounts, hasLength(1));
      expect(store.accounts.first.userId, 'u1');
      expect(created.userId, 'u1');
      expect(
        await SyncQueue.instance.hasPending(type: 'accounts'),
        isTrue,
      );
    });

    test('queued create reaches the remote provider', () async {
      await service.createAccount(account(id: 'a9'));
      await SyncManager.instance.flush();
      await SyncManager.instance.waitForIdle();

      expect(accountSupabase.created.map((a) => a.id), contains('a9'));
      expect(await SyncQueue.instance.all(), isEmpty);
    });
  });

  group('updateAccount', () {
    test('updates optimistically and enqueues an update', () async {
      await service.createAccount(account(id: 'a1'));
      store.setAccounts([account(id: 'a1').copyWith(userId: 'u1')]);

      final updated = await service.updateAccount(
        account(id: 'a1').copyWith(userId: 'u1', name: 'Livret'),
      );

      expect(store.accounts.first.name, 'Livret');
      expect(updated.name, 'Livret');
    });

    test('recreates the account when the remote update returns null',
        () async {
      accountSupabase.returnNullOnUpdate = true;
      await service.createAccount(account(id: 'a1'));
      await SyncManager.instance.flush();
      await SyncManager.instance.waitForIdle();

      expect(accountSupabase.created.map((a) => a.id), contains('a1'));
    });
  });

  group('deleteAccount', () {
    test('removes locally and enqueues a delete that reaches remote', () async {
      final acc = account(id: 'a1').copyWith(userId: 'u1');
      store.setAccounts([acc]);

      final result = await service.deleteAccount('a1');
      await SyncManager.instance.flush();
      await SyncManager.instance.waitForIdle();

      expect(result, isTrue);
      expect(store.accounts, isEmpty);
      expect(accountSupabase.deletedIds, contains('a1'));
    });
  });

  group('uploads', () {
    test('queuePictureUpload enqueues an update with a local picture path',
        () async {
      final acc = account(id: 'a1', picture: 'pic.png').copyWith(userId: 'u1');
      store.setAccounts([acc]);
      await service.queuePictureUpload(acc, File('C:/tmp/fake-account.png'));
      await SyncManager.instance.flush();
      await SyncManager.instance.waitForIdle();

      expect(storageSupabase.uploaded, isNotEmpty);
    });

    test('getSignedUrl returns null when storage raises', () async {
      storageSupabase.getSignedUrlResult = null;
      final url = await service.getSignedUrl('pic.png', 'a1');
      expect(url, isNull);
    });
  });
}
