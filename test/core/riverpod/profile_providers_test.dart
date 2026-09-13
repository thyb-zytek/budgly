import 'package:budgly/src/core/riverpod/profile_providers.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(() {
    ProfileStore.instance.clear();
  });

  group('profileServiceProvider', () {
    test('exposes the ProfileService singleton', () {
      final service = container.read(profileServiceProvider);
      expect(service, same(ProfileService.instance));
    });

    test('reading it repeatedly returns the same instance (keepAlive)', () {
      final first = container.read(profileServiceProvider);
      container.invalidate(profileServiceProvider);
      final second = container.read(profileServiceProvider);

      // ProfileService.instance is a plain singleton: even if the
      // *provider* were rebuilt, the underlying object must stay the same
      // one, so no session state can ever be lost due to a Riverpod
      // rebuild.
      expect(first, same(second));
    });
  });

  group('profileSessionProvider', () {
    test('initial state mirrors ProfileStore', () {
      final state = container.read(profileSessionProvider);

      expect(state.currentUser, ProfileStore.instance.currentUser);
      expect(state.hasLoaded, ProfileStore.instance.hasLoaded);
      expect(state.themeMode, ProfileStore.instance.themeMode);
      expect(state.locale, ProfileStore.instance.locale);
      expect(state.currency, ProfileStore.instance.currency);
      expect(state.amountDecimalPlaces, ProfileStore.instance.amountDecimalPlaces);
    });

    test('reflects preference mutations made outside Riverpod', () {
      container.read(profileSessionProvider); // ensure build() ran

      var notifications = 0;
      container.listen(profileSessionProvider, (previous, next) => notifications++);

      ProfileStore.instance.setPreferences(
        themeMode: ThemeMode.dark,
        currency: 'USD',
      );

      final state = container.read(profileSessionProvider);
      expect(state.themeMode, ThemeMode.dark);
      expect(state.currency, 'USD');
      expect(notifications, greaterThanOrEqualTo(1));
    });

    test('reflects setUser / clear', () {
      container.read(profileSessionProvider);

      final user = User(
        id: 'u1',
        email: 'user@example.com',
        emailVerified: true,
        provider: AuthProvider.email,
        profile: UserProfile(
          id: 'u1',
          email: 'user@example.com',
          fullName: 'Test User',
          currency: 'EUR',
          amountDecimalPlaces: 2,
          onboardingCompleted: true,
        ),
      );

      ProfileStore.instance.setUser(user);
      expect(container.read(profileSessionProvider).currentUser?.id, 'u1');
      expect(container.read(profileSessionProvider).hasLoaded, isTrue);

      ProfileStore.instance.clear();
      expect(container.read(profileSessionProvider).currentUser, isNull);
      expect(container.read(profileSessionProvider).hasLoaded, isFalse);
    });

    test('== / hashCode are value-based (needed for .select())', () {
      const a = ProfileSessionState(
        currentUser: null,
        hasLoaded: false,
        themeMode: ThemeMode.system,
        locale: Locale('fr'),
        currency: 'EUR',
        amountDecimalPlaces: 2,
      );
      const b = ProfileSessionState(
        currentUser: null,
        hasLoaded: false,
        themeMode: ThemeMode.system,
        locale: Locale('fr'),
        currency: 'EUR',
        amountDecimalPlaces: 2,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('disposing the container detaches the store listener without error', () {
      final localContainer = ProviderContainer();
      localContainer.read(profileSessionProvider);
      localContainer.dispose();

      expect(
        () => ProfileStore.instance.setPreferences(currency: 'GBP'),
        returnsNormally,
      );
    });
  });
}
