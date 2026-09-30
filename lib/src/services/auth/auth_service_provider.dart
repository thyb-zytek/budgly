import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_service_provider.g.dart';

/// Riverpod-owned authentication service dependency.
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) =>
    AuthService(analytics: ref.read(analyticsServiceProvider));
