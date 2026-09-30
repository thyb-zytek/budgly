import 'package:budgly/src/core/auth/auth_session.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_session_provider.g.dart';

/// Riverpod-owned Listenable bridge for Firebase Auth state changes.
///
/// The provider owns the notifier lifecycle. There is intentionally no
/// process-global AuthSessionNotifier singleton.
@Riverpod(keepAlive: true)
Raw<AuthSessionNotifier> authSessionNotifier(Ref ref) {
  final notifier = AuthSessionNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
}

/// Monotonic revision counter, incremented every time the underlying
/// [AuthSessionNotifier] fires. Consumers that need the actual user still read
/// it from [profileSessionProvider]; this only tells them when to re-check.
@Riverpod(keepAlive: true)
class AuthSessionRevision extends _$AuthSessionRevision {
  @override
  int build() {
    final notifier = ref.watch(authSessionProvider);
    notifier.addListener(_onAuthChanged);
    ref.onDispose(() => notifier.removeListener(_onAuthChanged));
    return 0;
  }

  void _onAuthChanged() {
    state = state + 1;
  }
}
