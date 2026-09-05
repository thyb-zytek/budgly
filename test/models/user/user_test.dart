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

  test('fromJson and toJson round-trip profile and identity fields', () {
    final user = User.fromJson({
      'id': 'u-json',
      'email': 'json@example.com',
      'email_verified': true,
      'avatar_url': 'https://example.com/avatar.png',
      'profile': {
        'user_id': 'u-json',
        'email': 'json@example.com',
        'full_name': 'Json User',
        'accounts': [],
      },
    });

    expect(user.id, 'u-json');
    expect(user.email, 'json@example.com');
    expect(user.emailVerified, isTrue);
    expect(user.avatarUrl.toString(), 'https://example.com/avatar.png');
    expect(user.hasProfile, isTrue);

    final json = user.toJson();
    expect(json['id'], 'u-json');
    expect(json['email_verified'], isTrue);
    expect(json['avatar_url'], 'https://example.com/avatar.png');
    expect(json['profile'], isA<Map<String, dynamic>>());
  });

  test('empty id is not authenticated', () {
    expect(User(id: '').isAuthenticated, isFalse);
    expect(User(id: 'u1').isAuthenticated, isTrue);
  });
}
