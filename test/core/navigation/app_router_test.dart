import 'dart:async';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/navigation/app_router.dart';
import 'package:budgly/src/core/navigation/app_routes.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_backend_client_overrides.dart';

void main() {
  test('parses a valid period from route query parameters', () {
    expect(
      AppRouter.parsePeriod(Uri.parse('/overview?year=2026&month=9')),
      const Period(year: 2026, month: 9),
    );
  });

  test(
    'falls back to current period for missing or invalid route parameters',
    () {
      final expected = Period.current();
      expect(AppRouter.parsePeriod(Uri.parse('/overview')), expected);
      expect(
        AppRouter.parsePeriod(Uri.parse('/overview?year=2026&month=13')),
        expected,
      );
      expect(
        AppRouter.parsePeriod(Uri.parse('/overview?year=2026&month=0')),
        expected,
        reason: 'month must be in the 1-12 range',
      );
      expect(
        AppRouter.parsePeriod(Uri.parse('/overview?year=not-a-number&month=9')),
        expected,
      );
      expect(
        AppRouter.parsePeriod(Uri.parse('/overview?year=2026')),
        expected,
        reason: 'month alone missing must not produce a half-parsed period',
      );
    },
  );

  testWidgets('refreshes redirects directly from the injected auth stream', (
    tester,
  ) async {
    final authEvents = StreamController<Object?>.broadcast(sync: true);
    addTearDown(authEvents.close);

    MockUser? firebaseUser = MockUser(uid: 'user-a', isEmailVerified: true);
    final profile = User(
      id: 'user-a',
      email: 'a@budgly.app',
      emailVerified: true,
      profile: UserProfile(
        id: 'user-a',
        email: 'a@budgly.app',
        fullName: 'User A',
        onboardingCompleted: true,
      ),
    );

    final appRouter = AppRouter(
      authStateChanges: authEvents.stream,
      readAuthUser: () => firebaseUser,
      readProfileSession: () => ProfileSessionState(
        currentUser: firebaseUser == null ? null : profile,
        hasLoaded: true,
        themeMode: ThemeMode.system,
        locale: const Locale('fr'),
        currency: 'EUR',
        amountDecimalPlaces: 2,
      ),
    );
    addTearDown(appRouter.dispose);

    // GoRouter resolves its initial route and redirects only once attached to a
    // Router. A bounded pump is used instead of pumpAndSettle because the
    // Overview page renders an indefinite loading indicator while its data
    // loads, which pumpAndSettle would wait on forever.
    await tester.pumpWidget(
      ProviderScope(
        overrides: testBackendClientOverrides(),
        child: MaterialApp.router(
          routerConfig: appRouter.router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('fr')],
        ),
      ),
    );
    await tester.pump();

    expect(
      appRouter.router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.overview,
    );

    firebaseUser = null;
    authEvents.add(null);
    await tester.pump();
    await tester.pump();

    expect(
      appRouter.router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.login,
    );
  });
}
