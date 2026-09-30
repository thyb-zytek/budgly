import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/supabase/categories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Mirrors `test/services/accounts/accounts_service_mutations_test.dart`: same
/// enqueue-first contract (docs/ARCHITECTURE.md), same risk (see
/// docs/AUDIT_PLAN.md, D3/D4), just for `CategoriesService` — which had no
/// dedicated coverage of its own even though the mutation logic was rewritten
/// at the same time as accounts.

class _FakeCategorySupabase extends CategorySupabase {
  _FakeCategorySupabase(this.remote);

  final List<Category> remote;

  @override
  Future<List<Category>> listByAccountId(String accountId) async =>
      remote.where((c) => c.accountId == accountId).toList();
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
  late LocalCache cache;

  Category category(String id, {String accountId = 'a1'}) =>
      Category(id: id, accountId: accountId, name: id);

  CategoriesService service({
    List<Category> remote = const [],
    SyncQueue? queue,
  }) => CategoriesService(
    categorySupabase: _FakeCategorySupabase(remote),
    analytics: AnalyticsService(),
    syncManager: testSyncManager,
    syncQueue: queue ?? testSyncQueue,
    localCache: cache,
  );

  setUp(() {
    cache = LocalCache();
  });

  test(
    'a category deleted offline is not resurrected by a revalidation',
    () async {
      final svc = service(remote: [category('c1'), category('c2')]);
      await svc.listCategoriesByAccount('a1');

      await svc.deleteCategory('c1', accountId: 'a1');
      svc.invalidateCache();
      final reloaded = await svc.listCategoriesByAccount(
        'a1',
        forceRefresh: true,
      );

      expect(reloaded.map((c) => c.id), ['c2']);
      expect((await cache.loadCategories('a1'))!.map((c) => c.id), ['c2']);
    },
  );

  test(
    'a category created offline survives a revalidation that does not know it',
    () async {
      final svc = service(remote: [category('remote1')]);
      await svc.listCategoriesByAccount('a1');

      final created = await svc.createCategory(
        const Category(accountId: 'a1', name: 'Offline'),
      );
      svc.invalidateCache();
      final reloaded = await svc.listCategoriesByAccount(
        'a1',
        forceRefresh: true,
      );

      expect(reloaded.map((c) => c.id), containsAll(['remote1', created.id]));
    },
  );

  test('a queue failure is reported and leaves the cache untouched', () async {
    final svc = service(remote: [category('c1')], queue: _BrokenQueue());
    await svc.listCategoriesByAccount('a1');

    await expectLater(
      svc.createCategory(
        const Category(accountId: 'a1', name: 'Never persisted'),
      ),
      throwsStateError,
    );
    await expectLater(svc.updateCategory(category('c1')), throwsStateError);
    await expectLater(
      svc.deleteCategory('c1', accountId: 'a1'),
      throwsStateError,
    );

    expect((await cache.loadCategories('a1'))!.map((c) => c.id), ['c1']);
  });

  test(
    'the durable queue entry exists as soon as createCategory returns',
    () async {
      final svc = service();
      final created = await svc.createCategory(
        const Category(accountId: 'a1', name: 'Main'),
      );

      final operations = await testSyncQueue.forType('categories');
      expect(operations.single.operation, 'create');
      expect(operations.single.entityId, created.id);
    },
  );

  test(
    'a delete without an accountId still enqueues, just skips the cache mirror',
    () async {
      final svc = service(remote: [category('c1')]);
      await svc.listCategoriesByAccount('a1');

      final result = await svc.deleteCategory('c1');

      expect(result, isTrue);
      final operations = await testSyncQueue.forType('categories');
      expect(operations.single.payload['account_id'], isNull);
      // Never mirrored anywhere, but the cached snapshot for a1 must be left
      // exactly as it was rather than corrupted.
      expect((await cache.loadCategories('a1'))!.map((c) => c.id), ['c1']);
    },
  );

  test(
    'concurrent creations never overwrite each other in the cache',
    () async {
      final svc = service();
      await Future.wait([
        for (var i = 0; i < 10; i++)
          svc.createCategory(Category(accountId: 'a1', name: 'C$i')),
      ]);

      expect(await cache.loadCategories('a1'), hasLength(10));
      expect(await testSyncQueue.forType('categories'), hasLength(10));
    },
  );
}
