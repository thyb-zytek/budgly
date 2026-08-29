import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User.isGoogleUser', () {
    test('is true for google provider', () {
      final user = User(
        id: 'u1',
        email: 'test@gmail.com',
        provider: AuthProvider.google,
      );
      expect(user.isGoogleUser, isTrue);
    });

    test('is false for email provider', () {
      final user = User(
        id: 'u1',
        email: 'test@example.com',
        provider: AuthProvider.email,
      );
      expect(user.isGoogleUser, isFalse);
    });
  });

  group('User.copyWith', () {
    test('preserves google provider by default', () {
      final user = User(
        id: 'u1',
        email: 'test@gmail.com',
        provider: AuthProvider.google,
        profile: UserProfile(
          id: 'u1',
          email: 'test@gmail.com',
          fullName: 'Old Name',
        ),
      );

      // Simulates a remote/local profile update (e.g. name change) that only
      // touches the profile, not the authentication provider.
      final copy = user.copyWith(
        profile: user.profile!.copyWith(fullName: 'New Name'),
      );

      expect(copy.profile!.fullName, 'New Name');
      expect(copy.isGoogleUser, isTrue);
      expect(copy.provider, AuthProvider.google);
    });

    test('can override provider explicitly', () {
      final user = User(
        id: 'u1',
        email: 'test@example.com',
        provider: AuthProvider.google,
      );

      final copy = user.copyWith(provider: AuthProvider.email);

      expect(copy.provider, AuthProvider.email);
      expect(copy.isGoogleUser, isFalse);
    });

    test('preserves provider when only id/email change', () {
      final user = User(
        id: 'u1',
        email: 'old@gmail.com',
        provider: AuthProvider.google,
      );

      final copy = user.copyWith(email: 'new@gmail.com');

      expect(copy.provider, AuthProvider.google);
      expect(copy.isGoogleUser, isTrue);
    });
  });
}
