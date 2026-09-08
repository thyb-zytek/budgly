import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/providers/supabase/user_profiles.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';

class FakeUserProfileSupabase extends UserProfileSupabase {
  int updateCalls = 0;
  Map<String, dynamic>? lastUpdates;
  String? lastUserId;
  Object? updateError;
  bool online = true;
  final Map<String, UserProfile> profiles = {};

  @override
  Future<UserProfile?> getProfile(String userId) async {
    return profiles[userId];
  }

  @override
  Future<UserProfile> getOrCreateProfile(fb.User firebaseUser) async {
    return profiles[firebaseUser.uid] ?? Fixtures.profile(id: firebaseUser.uid);
  }

  @override
  Future<bool> updateProfile(String userId, Map<String, dynamic> updates) async {
    if (!online) throw StateError('offline');
    updateCalls++;
    lastUserId = userId;
    lastUpdates = updates;
    if (updateError != null) throw updateError!;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeUserProfileSupabase profileSupabase;
  late ProfileService service;
  late SharedPreferences prefs;

  User seededUser(UserProfile profile) => User(
        id: 'u1',
        email: 'test@budgly.app',
        profile: profile,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    ProfileStore.instance.clear();
    profileSupabase = FakeUserProfileSupabase();
    service = ProfileService(
      store: ProfileStore.instance,
      profileSupabase: profileSupabase,
    );
  });

  tearDown(() async {
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    ProfileStore.instance.clear();
  });

  group('preferences', () {
    test('setThemeMode persists and enqueues the theme', () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1')),
      );

      await service.setThemeMode(ThemeMode.dark);

      expect(prefs.getInt(AppConstants.themeKey), ThemeMode.dark.index);
      expect(service.themeMode, ThemeMode.dark);
      expect(
        await SyncQueue.instance.hasPending(type: 'user_profiles'),
        isTrue,
      );
    });

    test('setThemeMode is a no-op when the theme is unchanged', () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1')),
      );
      await service.setThemeMode(ThemeMode.system);

      final before = await SyncQueue.instance.all();

      await service.setThemeMode(ThemeMode.system);

      expect((await SyncQueue.instance.all()).length, before.length);
      expect(service.themeMode, ThemeMode.system);
    });

    test('setLocale persists and enqueues the locale', () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1')),
      );

      await service.setLocale(const Locale('en'));

      expect(prefs.getString(AppConstants.localeKey), 'en');
      expect(service.locale.languageCode, 'en');
    });

    test('setCurrency persists and enqueues the currency', () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1')),
      );

      await service.setCurrency('USD');

      expect(prefs.getString(AppConstants.currencyKey), 'USD');
      expect(service.currency, 'USD');
    });

    test('setAmountDecimalPlaces clamps and persists', () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1')),
      );

      await service.setAmountDecimalPlaces(0);
      expect(service.amountDecimalPlaces, 0);

      await service.setAmountDecimalPlaces(99);
      expect(service.amountDecimalPlaces, 2);
    });
  });

  group('profile data', () {
    test('updateUserName updates the store and enqueues a profile update',
        () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1', fullName: 'Avant')),
      );

      await service.updateUserName('Après');

      expect(service.currentUser?.profile?.fullName, 'Après');
      expect(
        await SyncQueue.instance.hasPending(type: 'user_profiles'),
        isTrue,
      );
    });

    test('updateUserName is a no-op without a stored user', () async {
      await service.updateUserName('Qui');

      expect(service.currentUser, isNull);
      expect(await SyncQueue.instance.all(), isEmpty);
    });

    test('completeOnboarding flips the flag and enqueues a sync', () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1', onboardingCompleted: false)),
      );

      await service.completeOnboarding();

      expect(service.onboardingCompleted, isTrue);
      expect(
        await SyncQueue.instance.hasPending(type: 'user_profiles'),
        isTrue,
      );
    });

    test('completeOnboarding is skipped once already completed', () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1', onboardingCompleted: true)),
      );

      await service.completeOnboarding();

      expect(await SyncQueue.instance.all(), isEmpty);
    });

    test('the queued preference update reaches the remote provider', () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1', currency: 'EUR')),
      );

      await service.setCurrency('USD');
      await SyncManager.instance.flush();
      await SyncManager.instance.waitForIdle();

      expect(profileSupabase.updateCalls, greaterThan(0));
      expect(profileSupabase.lastUserId, 'u1');
      expect(profileSupabase.lastUpdates?['currency'], 'USD');
    });

    test('a backed-off profile update replays when the app resumes', () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1', onboardingCompleted: false)),
      );
      profileSupabase.online = false;

      // Complete onboarding while offline: the queued update fails and every
      // retry pushes it further into backoff.
      await service.completeOnboarding();
      for (var i = 0; i < 3; i++) {
        await SyncManager.instance.flush(forceRetry: true);
      }
      expect(
        await SyncQueue.instance.hasPending(type: 'user_profiles'),
        isTrue,
      );

      // Connectivity returns. Regular flushes skip the backed-off operation,
      // which is exactly why the resume trigger must be a forced retry.
      profileSupabase.online = true;
      await SyncManager.instance.flush();
      expect(profileSupabase.updateCalls, 0);

      // Returning to the app replays the update despite the backoff window.
      SyncManager.instance.start();
      SyncManager.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      for (var i = 0; i < 50; i++) {
        await SyncManager.instance.waitForIdle();
        if (!(await SyncQueue.instance.hasPending(type: 'user_profiles'))) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(profileSupabase.updateCalls, greaterThan(0));
      expect(profileSupabase.lastUserId, 'u1');
      expect(profileSupabase.lastUpdates?['onboarding_completed'], isTrue);
      expect(
        await SyncQueue.instance.hasPending(type: 'user_profiles'),
        isFalse,
      );
    });
  });

  group('sync preferences with server', () {
    test('syncPreferencesWithServer applies server preferences to the store',
        () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1', currency: 'EUR')),
      );
      final serverUser = User(
        id: 'u1',
        email: 'test@budgly.app',
        profile: UserProfile(
          id: 'u1',
          email: 'test@budgly.app',
          fullName: 'Test',
          themeMode: 'dark',
          language: 'en',
          currency: 'GBP',
          amountDecimalPlaces: 1,
        ),
      );

      await service.syncPreferencesWithServer(serverUser);

      expect(service.themeMode, ThemeMode.dark);
      expect(service.locale.languageCode, 'en');
      expect(service.currency, 'GBP');
      expect(service.amountDecimalPlaces, 1);
    });

    test('syncPreferencesWithServer ignores a user without a profile', () async {
      ProfileStore.instance.setPreferences(currency: 'EUR');

      await service.syncPreferencesWithServer(User(id: 'u2', email: 'x@y.z'));

      expect(service.currency, 'EUR');
    });

    test('onboarding_completed update sent when network resumes after offline tutorial', () async {
      ProfileStore.instance.setUser(
        seededUser(Fixtures.profile(id: 'u1', onboardingCompleted: false)),
      );
      profileSupabase.online = false;

      // Complete onboarding while offline – the update is queued but fails to send.
      await service.completeOnboarding();

      // Network is still offline; flushes should not succeed.
      await SyncManager.instance.flush(forceRetry: true);
      expect(
        await SyncQueue.instance.hasPending(type: 'user_profiles'),
        isTrue,
      );

      // Simulate network restoration.
      profileSupabase.online = true;
      await SyncManager.instance.flush();
      expect(profileSupabase.updateCalls, 0); // skipped because of backoff

      // Resume the app – the backed-off update should be replayed.
      SyncManager.instance.start();
      SyncManager.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      for (var i = 0; i < 50; i++) {
        await SyncManager.instance.waitForIdle();
        if (!(await SyncQueue.instance.hasPending(type: 'user_profiles'))) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(profileSupabase.updateCalls, greaterThan(0));
      expect(profileSupabase.lastUserId, 'u1');
      expect(profileSupabase.lastUpdates?['onboarding_completed'], isTrue);
      expect(
        await SyncQueue.instance.hasPending(type: 'user_profiles'),
        isFalse,
      );
    });
  });

  group('decimal places from the profile', () {
    MockFirebaseAuth signedInAuth() => MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', email: 'test@budgly.app'),
        );

    ProfileService serviceWithAuth(MockFirebaseAuth auth) => ProfileService(
          store: ProfileStore.instance,
          authService: AuthService(
            auth: auth,
            userProfileSupabase: profileSupabase,
          ),
          profileSupabase: profileSupabase,
        );

    test(
        'startup hydrates decimal places from the cached profile over device prefs',
        () async {
      SharedPreferences.setMockInitialValues({'amount_decimal_places': 2});
      final cachedProfile = UserProfile(
        id: 'u1',
        email: 'test@budgly.app',
        fullName: 'Test',
        amountDecimalPlaces: 0,
      );
      await LocalCache().saveProfile('u1', cachedProfile);

      final startupService = serviceWithAuth(signedInAuth());

      await startupService.init();

      // The connected profile's setting must win over the device-global value
      // (potentially left by another user), without waiting for a remote call.
      expect(startupService.currentUser?.id, 'u1');
      expect(startupService.amountDecimalPlaces, 0);
    });

    test('login applies decimal places from the cached profile immediately',
        () async {
      SharedPreferences.setMockInitialValues({'amount_decimal_places': 2});
      final cachedProfile = UserProfile(
        id: 'u1',
        email: 'test@budgly.app',
        fullName: 'Test',
        amountDecimalPlaces: 0,
      );
      await LocalCache().saveProfile('u1', cachedProfile);

      // A pending profile mutation (e.g. an offline edit) makes the background
      // remote refresh skip entirely, so the cached profile is the only source
      // that can apply the user's decimal setting.
      await SyncQueue.instance.enqueue(
        id: 'profile:update:u1',
        type: 'user_profiles',
        operation: 'update',
        payload: {'id': 'u1', 'amount_decimal_places': 1},
      );

      final loginService = serviceWithAuth(signedInAuth());

      await loginService.loadUserProfile(forceRefresh: true);

      expect(loginService.currentUser?.id, 'u1');
      expect(loginService.amountDecimalPlaces, 0);
    });
  });
}
