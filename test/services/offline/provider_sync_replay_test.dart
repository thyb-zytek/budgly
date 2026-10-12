import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:budgly/src/services/providers/supabase/categories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';

/// Replay of queued account/category mutations against the remote provider.
///
/// Covers what runs when the network comes back: idempotent creates, an update
/// whose row no longer exists (recreated, never silently dropped), and the
/// durable cross-backend cleanup that a successful delete schedules. A separate
/// queue/manager per test keeps these passes independent of the shared harness.

class _RecordingAccountSupabase extends AccountSupabase {
  final calls = <String>[];
  bool updateFindsRow = true;
  bool createSucceeds = true;
  Object? failWith;

  @override
  Future<Account?> create(Account account) async {
    calls.add('create:${account.id}');
    if (failWith != null) throw failWith!;
    return createSucceeds ? account : null;
  }

  @override
  Future<Account?> update(Account account) async {
    calls.add('update:${account.id}');
    if (failWith != null) throw failWith!;
    return updateFindsRow ? account : null;
  }

  @override
  Future<bool> delete(String accountId) async {
    calls.add('delete:$accountId');
    if (failWith != null) throw failWith!;
    return true;
  }
}

class _RecordingCategorySupabase extends CategorySupabase {
  final calls = <String>[];
  bool updateFindsRow = true;
  bool createSucceeds = true;
  Object? failWith;

  @override
  Future<Category?> create(Category category) async {
    calls.add('create:${category.id}');
    if (failWith != null) throw failWith!;
    return createSucceeds ? category : null;
  }

  @override
  Future<Category?> update(Category category) async {
    calls.add('update:${category.id}');
    if (failWith != null) throw failWith!;
    return updateFindsRow ? category : null;
  }

  @override
  Future<bool> delete(String categoryId) async {
    calls.add('delete:$categoryId');
    if (failWith != null) throw failWith!;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncQueue queue;
  late SyncManager manager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    queue = SyncQueue();
    manager = SyncManager(queue: queue, analytics: AnalyticsService());
  });

  tearDown(() async {
    await manager.resetForTest();
    await queue.clear();
  });

  Future<void> replay() async {
    await manager.flush(forceRetry: true);
    await manager.waitForIdle();
  }

  group('accounts', () {
    late _RecordingAccountSupabase remote;

    setUp(() {
      remote = _RecordingAccountSupabase();
      AccountsService(
        accountSupabase: remote,
        analytics: AnalyticsService(),
        syncManager: manager,
        syncQueue: queue,
        localCache: LocalCache(),
      ).registerSyncHandler(manager);
    });

    Future<void> enqueue(String operation, Map<String, dynamic> payload) =>
        queue.enqueue(
          id: 'account:$operation:${payload['id']}',
          type: 'accounts',
          operation: operation,
          payload: payload,
        );

    test('a queued create is sent once and leaves the queue', () async {
      await enqueue('create', Fixtures.account(id: 'a1').toJson());

      await replay();

      expect(remote.calls, ['create:a1']);
      expect(await queue.all(), isEmpty);
    });

    test('an update of an existing row does not recreate it', () async {
      await enqueue('update', Fixtures.account(id: 'a1').toJson());

      await replay();

      expect(remote.calls, ['update:a1']);
      expect(await queue.all(), isEmpty);
    });

    test('an update whose row is gone recreates it', () async {
      remote.updateFindsRow = false;
      await enqueue('update', Fixtures.account(id: 'a1').toJson());

      await replay();

      expect(remote.calls, ['update:a1', 'create:a1']);
      expect(await queue.all(), isEmpty);
    });

    test('a failed recreation keeps the operation queued', () async {
      remote
        ..updateFindsRow = false
        ..createSucceeds = false;
      await enqueue('update', Fixtures.account(id: 'a1').toJson());

      await replay();

      expect((await queue.all()).single.entityId, 'a1');
    });

    test('a remote failure keeps the operation queued for a retry', () async {
      remote.failWith = StateError('offline');
      await enqueue('create', Fixtures.account(id: 'a1').toJson());

      await replay();

      expect(await queue.all(), hasLength(1));
    });

    test('a successful delete schedules the durable cleanup and purges the account dependents', () async {
      await enqueue('delete', {'id': 'a1'});
      await queue.enqueue(
        id: 'category:create:c1',
        type: 'categories',
        operation: 'create',
        payload: {'id': 'c1', 'account_id': 'a1'},
      );
      await queue.enqueue(
        id: 'expense:create:e1',
        type: 'expenses',
        operation: 'create',
        payload: {'id': 'e1', 'accountId': 'a1'},
      );
      await queue.enqueue(
        id: 'category:create:c2',
        type: 'categories',
        operation: 'create',
        payload: {'id': 'c2', 'account_id': 'a2'},
      );

      await replay();

      expect(remote.calls, ['delete:a1']);
      final remaining = {for (final op in await queue.all()) op.id};
      // The account's own queued children are gone; another account's are not.
      expect(remaining, {'cleanup:account:a1', 'category:create:c2'});
    });

    test('a failed delete schedules no cleanup', () async {
      remote.failWith = StateError('offline');
      await enqueue('delete', {'id': 'a1'});

      await replay();

      final ids = {for (final op in await queue.all()) op.id};
      expect(ids, {'account:delete:a1'});
    });

    test('an unknown operation is not dropped', () async {
      await enqueue('weird', {'id': 'a1'});

      await replay();

      expect(await queue.all(), hasLength(1));
      expect(remote.calls, isEmpty);
    });
  });

  group('categories', () {
    late _RecordingCategorySupabase remote;

    setUp(() {
      remote = _RecordingCategorySupabase();
      CategoriesService(
        categorySupabase: remote,
        analytics: AnalyticsService(),
        syncManager: manager,
        syncQueue: queue,
        localCache: LocalCache(),
      ).registerSyncHandler(manager);
    });

    Map<String, dynamic> payload(String id) =>
        Fixtures.category(id: id, accountId: 'a1').toJson();

    Future<void> enqueue(String operation, Map<String, dynamic> payload) =>
        queue.enqueue(
          id: 'category:$operation:${payload['id']}',
          type: 'categories',
          operation: operation,
          payload: payload,
        );

    test('a queued create is sent once and leaves the queue', () async {
      await enqueue('create', payload('c1'));

      await replay();

      expect(remote.calls, ['create:c1']);
      expect(await queue.all(), isEmpty);
    });

    test('an update whose row is gone recreates it', () async {
      remote.updateFindsRow = false;
      await enqueue('update', payload('c1'));

      await replay();

      expect(remote.calls, ['update:c1', 'create:c1']);
      expect(await queue.all(), isEmpty);
    });

    test('a failed recreation keeps the operation queued', () async {
      remote
        ..updateFindsRow = false
        ..createSucceeds = false;
      await enqueue('update', payload('c1'));

      await replay();

      expect((await queue.all()).single.entityId, 'c1');
    });

    test(
      'a successful delete schedules the durable expenses cleanup',
      () async {
        await enqueue('delete', {'id': 'c1', 'account_id': 'a1'});

        await replay();

        expect(remote.calls, ['delete:c1']);
        expect(
          {for (final op in await queue.all()) op.id},
          {'cleanup:category:c1'},
        );
      },
    );

    test('a failed delete schedules no cleanup', () async {
      remote.failWith = StateError('offline');
      await enqueue('delete', {'id': 'c1', 'account_id': 'a1'});

      await replay();

      expect(
        {for (final op in await queue.all()) op.id},
        {'category:delete:c1'},
      );
    });

    test('an unknown operation is not dropped', () async {
      await enqueue('weird', {'id': 'c1'});

      await replay();

      expect(await queue.all(), hasLength(1));
      expect(remote.calls, isEmpty);
    });
  });
}
