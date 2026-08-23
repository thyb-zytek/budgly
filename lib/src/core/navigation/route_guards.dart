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

    if (!isLogin) return null;
    if (!user.emailVerified) return null;

    try {
      final refreshedUser = await AuthService.instance.reloadCurrentUser();
      final profile = refreshedUser?.profile;

      if (profile == null) return null;

      return profile.onboardingCompleted
          ? AppRoutes.overview
          : AppRoutes.tutorial;
    } catch (_) {
      return null;
    }
  }
}
