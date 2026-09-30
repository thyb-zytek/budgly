import 'package:budgly/src/core/auth/account_verification.dart';
import 'package:budgly/src/core/navigation/app_routes.dart';
import 'package:budgly/src/models/user/user.dart' as app_user;
import 'package:firebase_auth/firebase_auth.dart' as fb;

class RouteGuards {
  const RouteGuards._();

  /// Pure routing decision used by the router and unit tests.
  ///
  /// Keeping the decision independent from GoRouter makes authentication
  /// rules testable without constructing a full router.
  ///
  /// RL-01 §1.1/§2:
  /// * unauthenticated or unverified users only reach the login page (Google
  ///   accounts are verified automatically);
  /// * once the profile is known, `UserProfile.onboardingCompleted` decides
  ///   where the user belongs: an unfinished onboarding is confined to the
  ///   tutorial, a completed one bypasses it and lands on the Overview.
  static String? decideRedirect({
    required String location,
    fb.FirebaseAuth? auth,
    app_user.User? profileUser,
    bool hasLoaded = true,
  }) {
    final user = (auth ?? fb.FirebaseAuth.instance).currentUser;
    final isLogin = location == AppRoutes.login;

    if (user == null || !_isVerified(user)) {
      return isLogin ? null : AppRoutes.login;
    }

    // Wait for profile to be loaded before making routing decisions
    if (!hasLoaded) {
      return null;
    }

    final profile = profileUser?.profile;
    if (profile == null) {
      return null;
    }

    final isTutorial = location == AppRoutes.tutorial;
    if (profile.onboardingCompleted) {
      return isLogin || isTutorial ? AppRoutes.overview : null;
    }
    return isTutorial ? null : AppRoutes.tutorial;
  }

  static bool _isVerified(fb.User user) => isAccountVerified(
    emailVerified: user.emailVerified,
    providerIds: user.providerData.map((info) => info.providerId),
  );
}
