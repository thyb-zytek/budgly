import 'package:budgly/src/core/navigation/app_routes.dart';
import 'package:budgly/src/core/navigation/route_guards.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  User profileUser(bool completed) => User(
    id: 'u1',
    email: 'test@budgly.app',
    profile: UserProfile(
      id: 'u1',
      email: 'test@budgly.app',
      fullName: 'Test',
      onboardingCompleted: completed,
    ),
  );

  test('anonymous users are redirected to login', () {
    final auth = MockFirebaseAuth(signedIn: false);

    expect(
      RouteGuards.decideRedirect(
        location: AppRoutes.overview,
        authUser: auth.currentUser,
      ),
      AppRoutes.login,
    );
    expect(
      RouteGuards.decideRedirect(
        location: AppRoutes.login,
        authUser: auth.currentUser,
      ),
      isNull,
    );
  });

  test('unverified users stay on login and cannot access protected routes', () {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'u1',
        email: 'test@budgly.app',
        isEmailVerified: false,
      ),
    );

    expect(
      RouteGuards.decideRedirect(
        location: AppRoutes.overview,
        authUser: auth.currentUser,
      ),
      AppRoutes.login,
    );
    expect(
      RouteGuards.decideRedirect(
        location: AppRoutes.login,
        authUser: auth.currentUser,
      ),
      isNull,
    );
  });

  test('verified user without hydrated profile is not redirected', () {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'u1',
        email: 'test@budgly.app',
        isEmailVerified: true,
      ),
    );

    expect(
      RouteGuards.decideRedirect(
        location: AppRoutes.overview,
        authUser: auth.currentUser,
        profileUser: null,
      ),
      isNull,
    );
  });

  test('completed onboarding sends login to overview', () {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'u1',
        email: 'test@budgly.app',
        isEmailVerified: true,
      ),
    );

    expect(
      RouteGuards.decideRedirect(
        location: AppRoutes.login,
        authUser: auth.currentUser,
        profileUser: profileUser(true),
      ),
      AppRoutes.overview,
    );
  });

  test('incomplete onboarding sends login to tutorial', () {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'u1',
        email: 'test@budgly.app',
        isEmailVerified: true,
      ),
    );

    expect(
      RouteGuards.decideRedirect(
        location: AppRoutes.login,
        authUser: auth.currentUser,
        profileUser: profileUser(false),
      ),
      AppRoutes.tutorial,
    );
  });
}
