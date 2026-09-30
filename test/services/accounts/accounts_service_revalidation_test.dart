import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers.dart';

/// Returns a scripted response per call, so a test can distinguish the
/// account list a *background* revalidation fetched from the one a later,
/// explicit `forceRefresh` fetched.
class ScriptedAccountSupabase extends AccountSupabase {
  final List<List<Account>> responses;
  int calls = 0;

  ScriptedAccountSupabase(this.responses);

  @override
  Future<List<Account>> listByUserId(String userId) async {
    final response = responses[calls.clamp(0, responses.length - 1)];
    calls++;
    return response;
  }
}

void main() {
  final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));

  Account account(String id) => Account(id: id, name: id);

  AccountsService service(ScriptedAccountSupabase supabase) => AccountsService(
    accountSupabase: supabase,
    auth: auth,
    analytics: AnalyticsService(),
    syncManager: testSyncManager,
    syncQueue: testSyncQueue,
  );

  test(
    'a cache-hit background revalidation reaches onRevalidated instead of being silently dropped',
    () async {
      final supabase = ScriptedAccountSupabase([
        [account('remote1')],
      ]);
      final svc = service(supabase);
      // Seed the local cache so the first call takes the cache-first branch.
      await svc
          .loadAccounts(); // primes _loadedUserId + local cache miss -> awaits remote
      expect(supabase.calls, 1);
      // The priming call just marked the 1-minute refresh throttle as due;
      // reset it so the next call takes the cache-hit + background-refresh
      // branch under test instead of returning the cache with no refresh at
      // all (unrelated to the bug this test targets).
      svc.invalidateCache();

      final revalidated = <List<Account>>[];
      final cached = await svc.loadAccounts(onRevalidated: revalidated.add);
      // Cache now has 'remote1' from the priming call, so this call must
      // return the cached snapshot immediately, *and* fire a background
      // revalidation.
      expect(cached.map((a) => a.id), ['remote1']);

      // Let the unawaited background revalidation's microtasks run.
      await Future<void>.delayed(Duration.zero);
      expect(supabase.calls, 2);
      expect(revalidated, hasLength(1));
      expect(revalidated.single.map((a) => a.id), ['remote1']);
    },
  );

  test(
    'RL-01 §3.2: a background revalidation does not leak the in-flight guard '
    'and block a later forced refresh',
    () async {
      final supabase = ScriptedAccountSupabase([
        [account('remote1')], // priming call
        [account('remote1')], // background revalidation of the cache-hit call
        [account('remote2')], // explicit forceRefresh afterwards
      ]);
      final svc = service(supabase);
      await svc.loadAccounts();
      expect(supabase.calls, 1);
      svc.invalidateCache(); // see the previous test for why

      // Cache-hit call: returns cached data immediately, kicks off a
      // background revalidation.
      await svc.loadAccounts();
      await Future<void>.delayed(Duration.zero);
      expect(
        supabase.calls,
        2,
        reason: 'the background revalidation must actually run',
      );

      // Regression guard: before the fix, the in-flight guard registered for
      // the background revalidation was never released, so this forced call
      // would short-circuit on the stale completed future above and never
      // reach the network again.
      final forced = await svc.loadAccounts(forceRefresh: true);
      expect(supabase.calls, 3);
      expect(forced.map((a) => a.id), ['remote2']);
    },
  );
}
