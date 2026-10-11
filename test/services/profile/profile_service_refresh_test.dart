import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers.dart';

class _RefreshAuthService extends AuthService {
  _RefreshAuthService({
    required this.firebase,
    this.reloadedUser,
    this.reloadError,
    this.onReload,
  }) : super(auth: firebase, analytics: AnalyticsService());

  final MockFirebaseAuth firebase;
  final User? reloadedUser;
  final Object? reloadError;
  final Future<void> Function()? onReload;
  bool signedOut = false;

  @override
  Future<User?> reloadCurrentUser() async {
    final error = reloadError;
    if (error != null) throw error;
    await onReload?.call();
    return reloadedUser;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    await firebase.signOut();
  }
}

final _userA = User(
  id: 'user-a',
  provider: AuthProvider.email,
  profile: UserProfile(
    id: 'user-a',
    email: 'a@budgly.app',
    fullName: 'User A',
    currency: 'EUR',
  ),
);

void main() {
  late SyncManager manager;
  late SyncQueue queue;
  late ProfileService service;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    manager = testSyncManager;
    queue = testSyncQueue;
    service = ProfileService(
      analytics: AnalyticsService(),
      syncManager: manager,
      syncQueue: queue,
    );
    await manager.resetForTest();
    await queue.clear();
    // Keep the shared SyncManager test instance deterministic between tests.
    manager.registerHandler('__test_reset__', (op) async {});
    await manager.flush();
  });

  tearDown(() async {
    await manager.resetForTest();
  });

  test(
    'returns true when online: every pending mutation reaches the server',
    () async {
      await queue.enqueue(
        id: 'accounts:create:1',
        type: 'accounts',
        operation: 'create',
        payload: {'id': 'acc-1'},
      );

      // A handler that succeeds mimics reaching the server (online).
      manager.registerHandler('accounts', (op) async {});

      final online = await service.flushPendingMutations();

      expect(
        online,
        isTrue,
        reason: 'queue must be empty after a successful flush',
      );
      expect(await queue.all(), isEmpty);
    },
  );

  test('returns false when offline: a failing mutation stays queued', () async {
    await queue.enqueue(
      id: 'accounts:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': 'acc-1'},
    );

    // A handler that throws mimics an unreachable server (offline).
    manager.registerHandler('accounts', (op) async {
      throw Exception('network unreachable');
    });

    final online = await service.flushPendingMutations();

    expect(
      online,
      isFalse,
      reason: 'a pending mutation remains, device is offline',
    );
    expect(
      await queue.all(),
      hasLength(1),
      reason: 'nothing is dropped on failure',
    );
  });

  test(
    'refreshFromServer defers while a profile mutation is pending',
    () async {
      final firebase = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-a'),
      );
      final auth = _RefreshAuthService(
        firebase: firebase,
        reloadedUser: _userA,
        onReload: firebase.signOut,
      );
      final localService = ProfileService(
        authService: auth,
        analytics: AnalyticsService(),
        syncManager: manager,
        syncQueue: queue,
      );

      await queue.enqueue(
        id: 'profile-update',
        type: 'user_profiles',
        operation: 'update',
        payload: {'id': 'user-a', 'currency': 'USD'},
      );

      expect(await localService.refreshFromServer(), isNull);
      expect(auth.signedOut, isFalse);
    },
  );

  test('strict refresh preserves errors for the manual refresh path', () async {
    final firebase = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-a'),
    );
    final error = StateError('network unreachable');
    final auth = _RefreshAuthService(firebase: firebase, reloadError: error);
    final localService = ProfileService(
      authService: auth,
      analytics: AnalyticsService(),
      syncManager: manager,
      syncQueue: queue,
    );

    await expectLater(
      localService.refreshFromServer(rethrowErrors: true),
      throwsA(same(error)),
    );
  });

  test('remote profile snapshot cannot overwrite a preference mutation made during reload', () async {
    final firebase = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-a'),
    );
    final cache = LocalCache();
    await cache.saveProfile('user-a', _userA.profile!);
    late ProfileService localService;
    final auth = _RefreshAuthService(
      firebase: firebase,
      reloadedUser: _userA,
      onReload: () async {
        // Simulate a user changing preferences while the remote refresh is
        // awaiting its response. The stale response still contains EUR.
        await localService.savePreferences(
          _userA,
          themeMode: ThemeMode.system,
          locale: const Locale('fr'),
          currency: 'USD',
          amountDecimalPlaces: 2,
        );
      },
    );
    localService = ProfileService(
      authService: auth,
      analytics: AnalyticsService(),
      syncManager: manager,
      syncQueue: queue,
      localCache: cache,
    );
    manager.registerHandler('user_profiles', (operation) async {});

    final refreshed = await localService.refreshFromServer();

    expect(refreshed, isNull);
    expect((await cache.loadProfile('user-a'))?.currency, 'USD');
  });

  test('background refresh swallows transient errors', () async {
    final firebase = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-a'),
    );
    final auth = _RefreshAuthService(
      firebase: firebase,
      reloadError: StateError('offline'),
    );
    final localService = ProfileService(
      authService: auth,
      analytics: AnalyticsService(),
      syncManager: manager,
      syncQueue: queue,
    );

    expect(await localService.refreshFromServer(), isNull);
    expect(auth.signedOut, isFalse);
  });

  test(
    'invalidating auth errors sign out and do not crash background refresh',
    () async {
      final firebase = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-a'),
      );
      final auth = _RefreshAuthService(
        firebase: firebase,
        reloadError: const AuthenticationException(
          code: 'user-token-expired',
          message: 'token expired',
        ),
      );
      final localService = ProfileService(
        authService: auth,
        analytics: AnalyticsService(),
        syncManager: manager,
        syncQueue: queue,
      );

      expect(await localService.refreshFromServer(), isNull);
      expect(auth.signedOut, isTrue);
      expect(firebase.currentUser, isNull);
    },
  );

  test('stale auth session never returns the old user snapshot', () async {
    final firebase = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-a'),
    );
    final auth = _RefreshAuthService(
      firebase: firebase,
      reloadedUser: _userA,
      onReload: firebase.signOut,
    );
    final localService = ProfileService(
      authService: auth,
      analytics: AnalyticsService(),
      syncManager: manager,
      syncQueue: queue,
    );

    // The fake reload changes Firebase identity before returning its stale
    // snapshot, modelling a real auth/session race across an awaited call.
    expect(await localService.refreshFromServer(), isNull);
  });

  test('returns true when there are no pending mutations at all', () async {
    final online = await service.flushPendingMutations();

    expect(online, isTrue);
  });
}
