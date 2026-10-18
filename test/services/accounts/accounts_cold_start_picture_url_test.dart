import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:budgly/src/services/providers/supabase/storage.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAccountSupabase extends AccountSupabase {
  _FakeAccountSupabase(this.remote);

  final List<Account> remote;
  int calls = 0;

  @override
  Future<List<Account>> listByUserId(String userId) async {
    calls++;
    return List.of(remote);
  }
}

class _FakeStorageSupabase extends StorageSupabase {
  @override
  Future<String> getSignedUrl({
    required String bucketId,
    required String filePath,
    int validityInSeconds = 3600,
  }) async => 'https://storage.test/$filePath';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));

  AccountsService service({
    required _FakeAccountSupabase accountSupabase,
    required LocalCache cache,
  }) => AccountsService(
    accountSupabase: accountSupabase,
    storageSupabase: _FakeStorageSupabase(),
    auth: auth,
    analytics: AnalyticsService(),
    syncManager: SyncManager(queue: SyncQueue(), analytics: AnalyticsService()),
    syncQueue: SyncQueue(),
    localCache: cache,
  );

  test('cold start: cache-first load then background revalidation delivers the '
      'signed picture URL to onRevalidated', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = LocalCache();

    const remote = [Account(id: 'a1', name: 'Alpha', picture: 'pic.jpg')];

    // First run (no cache): a normal awaited load would store the account in
    // the cache. `toJson` deliberately omits the ephemeral signed URL.
    final first = service(
      accountSupabase: _FakeAccountSupabase(remote),
      cache: cache,
    );
    final primed = await first.loadAccounts();
    expect(primed.single.picture, 'pic.jpg');
    expect(
      primed.single.pictureUrl,
      isNotNull,
      reason: 'the priming load should resolve the signed URL',
    );

    // Simulate a cold start: a fresh service instance reading the same
    // durable cache, with no in-flight state.
    final revalidated = <List<Account>>[];
    final restarted = service(
      accountSupabase: _FakeAccountSupabase(remote),
      cache: cache,
    );
    final cached = await restarted.loadAccounts(onRevalidated: revalidated.add);
    expect(
      cached.single.pictureUrl,
      isNull,
      reason: 'the ephemeral signed URL is intentionally not cached',
    );

    await Future<void>.delayed(Duration.zero);

    expect(revalidated, hasLength(1));
    expect(
      revalidated.single.single.pictureUrl,
      isNotNull,
      reason:
          'the revalidation result handed to AccountsSession must keep the '
          'signed URL so the header can render the avatar',
    );
  });
}
