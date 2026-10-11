import 'package:budgly/src/core/dependencies/backend_clients_provider.dart';
import 'package:budgly/src/services/providers/supabase/user_profiles.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_service_provider.g.dart';

/// Riverpod-owned authentication service dependency.
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  final auth = ref.watch(firebaseAuthClientProvider);
  return AuthService(
    auth: auth,
    googleSignIn: ref.watch(googleSignInClientProvider),
    userProfileSupabase: UserProfileSupabase(
      client: ref.watch(supabaseClientProvider),
      auth: auth,
    ),
    analytics: ref.watch(analyticsServiceProvider),
  );
}
