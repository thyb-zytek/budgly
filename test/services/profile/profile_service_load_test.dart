import 'dart:async';

import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers.dart';

/// `loadUserProfile` is the startup path of the profile: local cache first for
/// the first frame, remote revalidation afterwards, one remote call shared by
/// concurrent callers of the same user.
class _CountingAuthService extends AuthService {
  _CountingAuthService({required this.firebase, required this.remote})
    : super(auth: firebase, analytics: AnalyticsService());

  final MockFirebaseAuth firebase;
  final User remote;
  int reloads = 0;
  Completer<void>? gate;

  @override
  Future<User?> reloadCurrentUser() async {
    reloads++;
    final pending = gate;
    if (pending != null) await pending.future;
    return remote;
  }
}

UserProfile _profile(String name, {String currency = 'EUR'}) => UserProfile(
  id: 'user-a',
  email: 'a@budgly.app',
  fullName: name,
  currency: currency,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth firebase;
  late LocalCache cache;
  late _CountingAuthService auth;
  late ProfileService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
    firebase = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-a', email: 'a@budgly.app'),
    );
    cache = LocalCache();
    auth = _CountingAuthService(
      firebase: firebase,
      remote: User(
        id: 'user-a',
        provider: AuthProvider.email,
        profile: _profile('Remote name'),
      ),
    );
    service = ProfileService(
      authService: auth,
      analytics: AnalyticsService(),
      syncManager: testSyncManager,
      syncQueue: testSyncQueue,
      localCache: cache,
    );
  });

  tearDown(() async {
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
  });

  test(
    'returns null without any remote call when nobody is signed in',
    () async {
      await firebase.signOut();

      expect(await service.loadUserProfile(), isNull);
      expect(auth.reloads, 0);
    },
  );

  test(
    'without a local copy the profile comes from the server and is cached',
    () async {
      final user = await service.loadUserProfile();

      expect(user?.profile?.fullName, 'Remote name');
      expect(auth.reloads, 1);
      expect((await cache.loadProfile('user-a'))?.fullName, 'Remote name');
    },
  );

  test('with a local copy the cached profile is returned and revalidated in the background', () async {
    await cache.saveProfile('user-a', _profile('Cached name'));
    auth.gate = Completer<void>();

    final user = await service.loadUserProfile();

    // The first render does not wait for the server.
    expect(user?.profile?.fullName, 'Cached name');
    await pumpEventQueue();
    expect(auth.reloads, 1);

    auth.gate!.complete();
    await pumpEventQueue();
    expect((await cache.loadProfile('user-a'))?.fullName, 'Remote name');
  });

  test('a forced refresh ignores the local copy', () async {
    await cache.saveProfile('user-a', _profile('Cached name'));

    final user = await service.loadUserProfile(forceRefresh: true);

    expect(user?.profile?.fullName, 'Remote name');
    expect(auth.reloads, 1);
  });

  test('concurrent loads of the same user share one remote call', () async {
    auth.gate = Completer<void>();

    final first = service.loadUserProfile();
    await pumpEventQueue();
    final second = service.loadUserProfile();
    await pumpEventQueue();
    auth.gate!.complete();
    final results = await Future.wait([first, second]);

    expect(auth.reloads, 1);
    expect(results.map((u) => u?.profile?.fullName), [
      'Remote name',
      'Remote name',
    ]);
  });

  test('a finished load is not reused by the next one', () async {
    await service.loadUserProfile();
    // The point is that the *completed* shared future is released, so the next
    // load starts a new remote call. The first load warms the local copy, and a
    // cache hit is served immediately with a background revalidation only — so
    // force the refresh to observe the new foreground call deterministically.
    await service.loadUserProfile(forceRefresh: true);

    expect(auth.reloads, 2);
  });
}
