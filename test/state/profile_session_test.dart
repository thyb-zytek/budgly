import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers.dart';

/// Returns a scripted [User] for both the cache-first and the background
/// refresh calls `ProfileSession._initialize()` makes, without touching the
/// network.
class _FakeAccountsService extends AccountsService {
  _FakeAccountsService()
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );

  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async => const [];
}

class _FakeCategoriesService extends CategoriesService {
  _FakeCategoriesService()
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );

  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
    void Function(List<Category>)? onRevalidated,
  }) async => const [];
}

class _FakeProfileService extends ProfileService {
  _FakeProfileService({required super.authService, required this.userToReturn})
    : super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );

  final User? userToReturn;

  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async =>
      userToReturn;

  @override
  Future<User?> refreshFromServer() async => userToReturn;
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('RL-01 §1.3: applying a profile writes its preferences through to the '
      "local per-uid cache, so a later session for the same uid doesn't have "
      'to wait for the profile to reload to paint correctly', () async {
    final auth = AuthService(
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'user-a')),
      analytics: AnalyticsService(),
    );
    final user = User(
      id: 'user-a',
      provider: AuthProvider.email,
      profile: UserProfile(
        id: 'user-a',
        email: 'a@budgly.app',
        fullName: 'User A',
        themeMode: 'dark',
        currency: 'USD',
        language: 'en',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        profileServiceProvider.overrideWithValue(
          _FakeProfileService(authService: auth, userToReturn: user),
        ),
        accountsServiceProvider.overrideWithValue(_FakeAccountsService()),
        categoriesServiceProvider.overrideWithValue(_FakeCategoriesService()),
      ],
    );
    addTearDown(container.dispose);

    // Let ProfileSession.build()'s unawaited _initialize() run to completion.
    container.read(profileSessionProvider);
    await _pump();
    await _pump();
    await _pump();
    await _pump();

    final service = container.read(profileServiceProvider);
    final cached = await service.loadLocalPreferences(uid: 'user-a');
    expect(
      cached.themeMode,
      ThemeMode.dark,
      reason:
          'the local mirror must have been updated as soon as the '
          'profile was applied to the session, not only via the explicit '
          'Preferences screen',
    );
    expect(cached.currency, 'USD');
  });

  test('RL-01 §1.3: signing out and restarting the app with nobody signed in '
      "never paints a previous user's leftover cached preferences", () async {
    final signedInAuth = AuthService(
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'user-a')),
      analytics: AnalyticsService(),
    );
    final userA = User(
      id: 'user-a',
      provider: AuthProvider.email,
      profile: UserProfile(
        id: 'user-a',
        email: 'a@budgly.app',
        fullName: 'User A',
        themeMode: 'dark',
        currency: 'USD',
      ),
    );
    final firstRun = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(signedInAuth),
        profileServiceProvider.overrideWithValue(
          _FakeProfileService(authService: signedInAuth, userToReturn: userA),
        ),
        accountsServiceProvider.overrideWithValue(_FakeAccountsService()),
        categoriesServiceProvider.overrideWithValue(_FakeCategoriesService()),
      ],
    );
    firstRun.read(profileSessionProvider);
    await _pump();
    await _pump();
    await _pump();
    await _pump();
    firstRun.dispose();

    // App restarts with nobody signed in (e.g. a fresh sign-out landed
    // before the process was killed): a brand-new session should see
    // system defaults, not the leftover cache from `user-a`.
    final signedOutAuth = AuthService(
      auth: MockFirebaseAuth(signedIn: false),
      analytics: AnalyticsService(),
    );
    final secondRun = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(signedOutAuth),
        profileServiceProvider.overrideWithValue(
          _FakeProfileService(authService: signedOutAuth, userToReturn: null),
        ),
        accountsServiceProvider.overrideWithValue(_FakeAccountsService()),
        categoriesServiceProvider.overrideWithValue(_FakeCategoriesService()),
      ],
    );
    addTearDown(secondRun.dispose);

    secondRun.read(profileSessionProvider);
    await _pump();
    await _pump();
    await _pump();
    await _pump();

    final state = secondRun.read(profileSessionProvider);
    expect(state.themeMode, ThemeMode.system);
    expect(state.currency, 'EUR');
  });
}
