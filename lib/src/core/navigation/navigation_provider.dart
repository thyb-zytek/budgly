import 'package:budgly/src/core/auth/auth_session_provider.dart';
import 'package:budgly/src/core/navigation/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authSession = ref.read(authSessionProvider);
  final router = AppRouter(authSession: authSession).router;
  ref.onDispose(router.dispose);
  return router;
});
