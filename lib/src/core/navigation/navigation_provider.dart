import 'package:budgly/src/core/navigation/app_router.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.read(authServiceProvider);
  final appRouter = AppRouter(
    authStateChanges: authService.authStateChanges,
    readAuthUser: () => authService.firebaseUser,
    readProfileSession: () => ref.read(profileSessionProvider),
  );

  // Authentication changes are handled inside AppRouter. Profile changes
  // also affect the redirect decision (loaded/onboarding), so the router must
  // re-evaluate when ProfileSession finishes or is reset without rebuilding
  // the router instance itself.
  ref.listen(profileSessionProvider, (_, _) {
    appRouter.router.refresh();
  });

  ref.onDispose(appRouter.dispose);
  return appRouter.router;
});
