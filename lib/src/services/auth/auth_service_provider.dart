import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_service_provider.g.dart';

/// Riverpod-facing exposure of [AuthService] (issue M3).
///
/// Not rewritten: 3 call sites still on `.instance` (`login`/`tutorial`
/// ViewModels, not yet migrated — issue M4). No `ChangeNotifier` state of
/// its own — plain pass-through, no listener wiring needed.
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => AuthService.instance;
