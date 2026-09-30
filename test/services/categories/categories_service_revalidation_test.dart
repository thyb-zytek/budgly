import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/providers/supabase/categories.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers.dart';

/// Returns a scripted response per call, so a test can distinguish a
/// background revalidation's result from a later explicit refresh's result.
class ScriptedCategorySupabase extends CategorySupabase {
  final List<List<Category>> responses;
  int calls = 0;

  ScriptedCategorySupabase(this.responses);

  @override
  Future<List<Category>> listByAccountId(String accountId) async {
    final response = responses[calls.clamp(0, responses.length - 1)];
    calls++;
    return response;
  }
}

void main() {
  Category category(String id) => Category(id: id, accountId: 'a1', name: id);

  CategoriesService service(ScriptedCategorySupabase supabase) =>
      CategoriesService(
        categorySupabase: supabase,
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );

  test(
    'a cache-hit background revalidation reaches onRevalidated instead of being silently dropped',
    () async {
      final supabase = ScriptedCategorySupabase([
        [category('remote1')],
      ]);
      final svc = service(supabase);
      await svc.listCategoriesByAccount('a1');
      expect(supabase.calls, 1);
      svc.invalidateCache();

      final revalidated = <List<Category>>[];
      final cached = await svc.listCategoriesByAccount(
        'a1',
        onRevalidated: revalidated.add,
      );
      expect(cached.map((c) => c.id), ['remote1']);

      await Future<void>.delayed(Duration.zero);
      expect(supabase.calls, 2);
      expect(revalidated, hasLength(1));
      expect(revalidated.single.map((c) => c.id), ['remote1']);
    },
  );

  test(
    'RL-01 §3.2: a background revalidation does not leak the in-flight guard '
    'and block a later forced refresh',
    () async {
      final supabase = ScriptedCategorySupabase([
        [category('remote1')], // priming call
        [category('remote1')], // background revalidation of the cache-hit call
        [category('remote2')], // explicit forceRefresh afterwards
      ]);
      final svc = service(supabase);
      await svc.listCategoriesByAccount('a1');
      expect(supabase.calls, 1);
      svc.invalidateCache();

      await svc.listCategoriesByAccount('a1');
      await Future<void>.delayed(Duration.zero);
      expect(
        supabase.calls,
        2,
        reason: 'the background revalidation must actually run',
      );

      final forced = await svc.listCategoriesByAccount(
        'a1',
        forceRefresh: true,
      );
      expect(supabase.calls, 3);
      expect(forced.map((c) => c.id), ['remote2']);
    },
  );
}
