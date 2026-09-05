import 'package:budgly/src/core/navigation/app_routes.dart';
import 'package:budgly/src/models/user/user.dart' as app_user;
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:go_router/go_router.dart';

class RouteGuards {
  const RouteGuards._();

  /// Routing is deliberately local-only. A redirect must never wait for a
  /// network request: Firebase restores the auth state locally and
  /// [ProfileService] hydrates its cached profile independently.
  static String? authRedirect(GoRouterState state) => decideRedirect(
        location: state.matchedLocation,
      );

  /// Pure routing decision used by [authRedirect] and unit tests.
  ///
  /// Keeping the decision independent from GoRouter makes authentication
  /// rules testable without constructing a full router.
  static String? decideRedirect({
    required String location,
    fb.FirebaseAuth? auth,
    app_user.User? profileUser,
  }) {
    final user = (auth ?? fb.FirebaseAuth.instance).currentUser;
    final isLogin = location == AppRoutes.login;

    if (user == null || !user.emailVerified) {
      return isLogin ? null : AppRoutes.login;
    }

    final profile =
        profileUser?.profile ?? ProfileService.instance.currentUser?.profile;
    if (profile == null) {
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
