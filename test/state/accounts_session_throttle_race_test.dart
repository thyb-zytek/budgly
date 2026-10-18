import 'dart:async';

import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:budgly/src/services/providers/supabase/storage.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Account backend whose remote read waits until [gate] completes, so a test
/// can hold a background revalidation open while a second load runs.
class _GatedAccountSupabase extends AccountSupabase {
  _GatedAccountSupabase(this.remote, this.gate);

  final List<Account> remote;
  final Future<void> gate;

  @override
  Future<List<Account>> listByUserId(String userId) async {
    await gate;
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
    required AccountSupabase accountSupabase,
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

  test('a second cold-start load() that hits the refresh throttle must not revert '
      'the session to the URL-less cache', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = LocalCache();
    // The durable cache never stores the ephemeral signed URL.
    await cache.saveAccounts('u1', [
      const Account(id: 'a1', name: 'Alpha', picture: 'pic.jpg'),
    ]);

    final gate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        accountsServiceProvider.overrideWithValue(
          service(
            accountSupabase: _GatedAccountSupabase(const [
              Account(id: 'a1', name: 'Alpha', picture: 'pic.jpg'),
            ], gate.future),
            cache: cache,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(accountsSessionProvider.notifier);

    // load #1: cache-first. The session gets the URL-less cache at once and a
    // background revalidation is scheduled.
    await session.load();
    expect(
      container.read(accountsSessionProvider).accounts.single.pictureUrl,
      isNull,
    );

    // The background revalidation resolves the signed URL.
    gate.complete();
    await pumpEventQueue();
    expect(
      container.read(accountsSessionProvider).accounts.single.pictureUrl,
      isNotNull,
      reason: 'the background revalidation must apply the signed URL',
    );

    // load #2: a second startup caller. The refresh throttle is still warm, so
    // this load returns the cache without scheduling a revalidation.
    await session.load();
    expect(
      container.read(accountsSessionProvider).accounts.single.pictureUrl,
      isNotNull,
      reason:
          'a throttled cache-first load must not discard the fresher signed '
          'URL already held by the session',
    );
  });
}
