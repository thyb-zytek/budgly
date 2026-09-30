import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/models/user/user.dart';
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

class _FakeProfileService extends ProfileService {
  _FakeProfileService({required super.authService})
    : super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );

  Object? changePasswordError;

  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async => null;

  @override
  Future<User?> refreshFromServer() async => null;

  @override
  Future<User> changePassword(String oldPassword, String newPassword) async {
    if (changePasswordError != null) throw changePasswordError!;
    return const User(id: 'u1', emailVerified: true);
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('validatePassword (pure)', () {
    test('an empty new password is required', () {
      expect(validatePassword('', 'newpass'), 'passwordRequired');
      expect(validatePassword(null, 'newpass'), 'passwordRequired');
    });

    test('confirmation field must match the live new-password value', () {
      expect(validatePassword('other', 'newpass'), 'passwordsDoNotMatch');
    });

    test('comparing the new-password field against itself always matches', () {
      // currentPassword is empty when validating the new-password field
      // itself, per the doc comment.
      expect(validatePassword('short', ''), 'passwordTooShort');
    });

    test('a match shorter than 6 characters is rejected', () {
      expect(validatePassword('abc', 'abc'), 'passwordTooShort');
    });

    test('a valid, matching password of sufficient length passes', () {
      expect(validatePassword('abcdef', 'abcdef'), isNull);
      expect(validatePassword('abcdef', ''), isNull);
    });
  });

  group('ProfileSettings.changePassword', () {
    test('reports a success message on success', () async {
      final container = _container(
        _FakeProfileService(
          authService: AuthService(analytics: AnalyticsService()),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(profileSettingsProvider.notifier)
          .changePassword(oldPassword: 'old', newPassword: 'newpass');

      final state = container.read(profileSettingsProvider);
      expect(state.hasError, isFalse);
      expect(state.pendingMessage, isNotNull);
    });

    test(
      'a password-change-failed AuthenticationException reports the dedicated message',
      () async {
        final service =
            _FakeProfileService(
                authService: AuthService(analytics: AnalyticsService()),
              )
              ..changePasswordError = const AuthenticationException(
                message: 'wrong password',
                code: 'password-change-failed',
              );
        final container = _container(service);
        addTearDown(container.dispose);

        await container
            .read(profileSettingsProvider.notifier)
            .changePassword(oldPassword: 'wrong', newPassword: 'newpass');

        final state = container.read(profileSettingsProvider);
        expect(state.hasError, isTrue);
        expect(state.pendingMessage, isNotNull);
      },
    );

    test(
      'any other error is still reported through the generic classifier',
      () async {
        final service = _FakeProfileService(
          authService: AuthService(analytics: AnalyticsService()),
        )..changePasswordError = Exception('network down');
        final container = _container(service);
        addTearDown(container.dispose);

        await container
            .read(profileSettingsProvider.notifier)
            .changePassword(oldPassword: 'old', newPassword: 'newpass');

        expect(container.read(profileSettingsProvider).hasError, isTrue);
      },
    );
  });

  test('consumeMessage clears the pending one-shot message', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(profileSettingsProvider.notifier);

    notifier.consumeMessage();

    expect(container.read(profileSettingsProvider).pendingMessage, isNull);
  });
}
