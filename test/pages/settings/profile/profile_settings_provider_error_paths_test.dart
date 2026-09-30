import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/pages/settings/profile/profile_settings_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers.dart';

/// Complements `profile_settings_provider_test.dart` (which only covers
/// `changePassword` and the pure `validatePassword`) with `loadUser`,
/// `onChangeName` and the offline branch of `refreshUser`.
///
/// `_isCurrentSession`'s guard only compares the *currently* signed-in uid
/// against the uid captured when the call started (both `null` here, a
/// signed-out mock auth), not against the loaded profile's own id — so a
/// fake `loadUserProfile` returning a non-null [User] is enough to populate
/// `ProfileSession.currentUser` without needing to also fake accounts or
/// categories (their own load call is separately guarded and short-circuits
/// for the same reason). This is what lets `onChangeName`'s tests below prime
/// a real `currentUser` with a single extra `load()` call.
class _FakeProfileService extends ProfileService {
  _FakeProfileService({required super.authService})
    : super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );

  User? userProfile;
  Object? loadUserError;
  Object? updateNameError;

  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async {
    if (loadUserError != null) throw loadUserError!;
    return userProfile;
  }

  @override
  Future<User?> refreshFromServer() async => null;

  @override
  Future<bool> flushPendingMutations() async => false;

  @override
  Future<User> updateUserName(User user, String name) async {
    if (updateNameError != null) throw updateNameError!;
    return user.copyWith(profile: user.profile?.copyWith(fullName: name));
  }
}

ProviderContainer _container(_FakeProfileService service) => ProviderContainer(
  overrides: [
    authServiceProvider.overrideWithValue(
      AuthService(
        auth: MockFirebaseAuth(signedIn: false),
        analytics: AnalyticsService(),
      ),
    ),
    profileServiceProvider.overrideWithValue(service),
  ],
);

User _user(String id) => User(
  id: id,
  profile: UserProfile(id: id, email: '$id@budgly.app', fullName: 'Alice'),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('loadUser', () {
    test('a successful load clears the loading status', () async {
      final service = _FakeProfileService(
        authService: AuthService(analytics: AnalyticsService()),
      );
      final container = _container(service);
      addTearDown(container.dispose);

      await container.read(profileSettingsProvider.notifier).loadUser();

      final state = container.read(profileSettingsProvider);
      expect(state.isLoading, isFalse);
      expect(state.hasError, isFalse);
    });

    test('a failure is reported', () async {
      final service = _FakeProfileService(
        authService: AuthService(analytics: AnalyticsService()),
      )..loadUserError = StateError('boom');
      final container = _container(service);
      addTearDown(container.dispose);

      await container.read(profileSettingsProvider.notifier).loadUser();

      expect(container.read(profileSettingsProvider).hasError, isTrue);
    });
  });

  group('onChangeName', () {
    test(
      'a successful rename updates ProfileSession and reports success',
      () async {
        final service = _FakeProfileService(
          authService: AuthService(analytics: AnalyticsService()),
        )..userProfile = _user('u1');
        final container = _container(service);
        addTearDown(container.dispose);
        // Primes ProfileSession.currentUser (see the class-level doc comment).
        await container.read(profileSessionProvider.notifier).load();

        await container
            .read(profileSettingsProvider.notifier)
            .onChangeName('Alicia');

        final state = container.read(profileSettingsProvider);
        expect(state.hasError, isFalse);
        expect(state.pendingMessage, isNotNull);
        expect(
          container.read(profileSessionProvider).currentUser?.profile?.fullName,
          'Alicia',
        );
      },
    );

    test(
      'a failure is reported and ProfileSession is left untouched',
      () async {
        final service = _FakeProfileService(
          authService: AuthService(analytics: AnalyticsService()),
        )..userProfile = _user('u1');
        final container = _container(service);
        addTearDown(container.dispose);
        await container.read(profileSessionProvider.notifier).load();

        service.updateNameError = StateError('boom');
        await container
            .read(profileSettingsProvider.notifier)
            .onChangeName('Alicia');

        final state = container.read(profileSettingsProvider);
        expect(state.hasError, isTrue);
        expect(
          container.read(profileSessionProvider).currentUser?.profile?.fullName,
          'Alice',
        );
      },
    );
  });

  group('refreshUser', () {
    test(
      'stays offline (pending mutations could not be flushed) and reports a failure without touching local data',
      () async {
        // flushPendingMutations() -> false is the default on this fake.
        final service = _FakeProfileService(
          authService: AuthService(analytics: AnalyticsService()),
        );
        final container = _container(service);
        addTearDown(container.dispose);

        await container.read(profileSettingsProvider.notifier).refreshUser();

        final state = container.read(profileSettingsProvider);
        expect(state.hasError, isTrue);
        expect(state.pendingMessage, isNotNull);
      },
    );
  });
}
