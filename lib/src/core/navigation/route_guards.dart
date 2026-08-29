import 'package:budgly/src/core/navigation/app_routes.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:go_router/go_router.dart';

class RouteGuards {
  const RouteGuards._();

  /// Routing is deliberately local-only. A redirect must never wait for a
  /// network request: Firebase restores the auth state locally and
  /// [ProfileService] hydrates its cached profile independently.
  static String? authRedirect(GoRouterState state) {
    final user = fb.FirebaseAuth.instance.currentUser;
    final isLogin = state.matchedLocation == AppRoutes.login;

    if (user == null) {
      return isLogin ? null : AppRoutes.login;
    }

    if (!user.emailVerified) {
      return isLogin ? null : AppRoutes.login;
    }

    final profile = ProfileService.instance.currentUser?.profile;
    if (profile == null) {
      // The profile may still be hydrating from disk/remote. Keep the current
      // route and let the router refresh when ProfileService notifies.
      return null;
    }

    if (isLogin) {
      return profile.onboardingCompleted
          ? AppRoutes.overview
          : AppRoutes.tutorial;
    }

    return null;
  }
}
