import 'package:budgly/src/core/navigation/app_routes.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:go_router/go_router.dart';

class RouteGuards {
  const RouteGuards._();

  static Future<String?> authRedirect(
    GoRouterState state,
  ) async {
    final user = fb.FirebaseAuth.instance.currentUser;
    final isLogin = state.matchedLocation == AppRoutes.login;

    if (user == null) {
      return isLogin ? null : AppRoutes.login;
    }

    // Only resolve the onboarding destination from the user profile.
    // Account loading is application data and must never be able to send
    // an already onboarded user back to the tutorial.
    if (!isLogin) return null;
    if (!user.emailVerified) return null;

    try {
      final refreshedUser = await AuthService.instance.reloadCurrentUser();
      final profile = refreshedUser?.profile;

      // If the profile cannot be resolved, do not guess that onboarding is
      // incomplete. Staying on the current route is safer than redirecting
      // an existing user into the tutorial because of a transient backend
      // failure.
      if (profile == null) return null;

      return profile.onboardingCompleted
          ? AppRoutes.overview
          : AppRoutes.tutorial;
    } catch (_) {
      return null;
    }
  }
}
