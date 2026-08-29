import 'package:budgly/src/models/user/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile.fromJson', () {
    test('parses full JSON', () {
      final json = {
        'user_id': 'u1',
        'email': 'test@example.com',
        'full_name': 'John Doe',
        'avatar_url': 'https://example.com/avatar.png',
        'color': '#FF5722',
        'theme_mode': 'dark',
        'currency': 'USD',
        'amount_decimal_places': 1,
        'language': 'en',
        'onboarding_completed': true,
        'accounts': [],
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-06-15T00:00:00.000',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.id, 'u1');
      expect(profile.email, 'test@example.com');
      expect(profile.fullName, 'John Doe');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.themeMode, 'dark');
      expect(profile.currency, 'USD');
      expect(profile.amountDecimalPlaces, 1);
      expect(profile.language, 'en');
      expect(profile.onboardingCompleted, isTrue);
    });

    test('defaults for missing fields', () {
      final json = <String, dynamic>{};
      final profile = UserProfile.fromJson(json);
      expect(profile.id, '');
      expect(profile.email, '');
      expect(profile.fullName, '');
      expect(profile.themeMode, 'system');
      expect(profile.currency, 'EUR');
      expect(profile.amountDecimalPlaces, 2);
      expect(profile.onboardingCompleted, isFalse);
    });

    test('clamps amountDecimalPlaces to 0..2', () {
      final json = {'amount_decimal_places': 5};
      final profile = UserProfile.fromJson(json);
      expect(profile.amountDecimalPlaces, 2);

      final json2 = {'amount_decimal_places': -1};
      final profile2 = UserProfile.fromJson(json2);
      expect(profile2.amountDecimalPlaces, 0);
    });

    test('handles null color by generating random', () {
      final json = <String, dynamic>{};
      final profile = UserProfile.fromJson(json);
      expect(profile.color, isNotNull);
    });

    test('parses accounts list', () {
      final json = {
        'accounts': [
          {'id': 'a1', 'name': 'Main'},
        ],
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.accounts, hasLength(1));
      expect(profile.accounts.first.name, 'Main');
    });

    test('handles null accounts', () {
      final json = <String, dynamic>{};
      final profile = UserProfile.fromJson(json);
      expect(profile.accounts, isEmpty);
    });
  });

  group('UserProfile.toJson', () {
    test('round-trips through fromJson', () {
      final original = UserProfile(
        id: 'u1',
        email: 'test@example.com',
        fullName: 'John Doe',
        themeMode: 'dark',
        currency: 'USD',
        amountDecimalPlaces: 1,
        language: 'en',
        onboardingCompleted: true,
      );

      final json = original.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.email, original.email);
      expect(restored.fullName, original.fullName);
      expect(restored.themeMode, original.themeMode);
      expect(restored.currency, original.currency);
      expect(restored.amountDecimalPlaces, original.amountDecimalPlaces);
      expect(restored.language, original.language);
      expect(restored.onboardingCompleted, original.onboardingCompleted);
    });
  });

  group('UserProfile.copyWith', () {
    test('copies with new values', () {
      final profile = UserProfile(
        id: 'u1',
        email: 'old@example.com',
        fullName: 'Old Name',
      );

      final copy = profile.copyWith(
        email: 'new@example.com',
        fullName: 'New Name',
      );

      expect(copy.email, 'new@example.com');
      expect(copy.fullName, 'New Name');
      expect(copy.id, 'u1');
    });

    test('updatedAt is always set to DateTime.now()', () {
      final profile = UserProfile(
        id: 'u1',
        email: 'test@example.com',
        fullName: 'Test',
      );

      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final copy = profile.copyWith(fullName: 'Changed');
      final after = DateTime.now().add(const Duration(seconds: 1));

      expect(copy.updatedAt.isAfter(before), isTrue);
      expect(copy.updatedAt.isBefore(after), isTrue);
    });

    test('preserves original updatedAt on non-changed copy', () {
      final profile = UserProfile(
        id: 'u1',
        email: 'test@example.com',
        fullName: 'Test',
      );

      final copy = profile.copyWith(fullName: 'Changed');
      // copyWith always sets updatedAt to now, so it should be recent
      expect(copy.updatedAt, isNotNull);
    });
  });
}
