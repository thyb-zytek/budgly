import 'package:budgly/src/core/auth/auth_session.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_session_provider.g.dart';

/// Riverpod-observable mirror of [AuthSessionNotifier] (issue M2).
///
/// This is the store I missed in the first M2 pass: it lives under
/// `core/auth/` rather than `stores/`, but it's structurally the same thing
/// — a `ChangeNotifier` singleton (`.instance`). It is read directly by
/// `app_router.dart`'s `refreshListenable`, built statically
/// (`static final GoRouter router = ...`) outside any `ProviderScope` — same
/// reasoning as `ProfileService`/`ProfileStore` for not rewriting it
/// (issue M1b).
///
/// Unlike the other four stores mirrored in M2, [AuthSessionNotifier]
/// exposes no mutable data of its own to mirror — it only relays Firebase
/// Auth's state-change stream (its role is purely to be a
/// [Listenable] trigger for the router). It also has no way to be triggered
/// in a test through `.instance` (the stream is wired to the real
/// `FirebaseAuth.instance` unless a different `auth` is injected at
/// construction time, and the singleton doesn't expose that afterwards).
/// So, unlike the other three store mirrors, this one goes through a
/// provider-pont for the notifier itself, exactly like `profileService` in
/// [profile_providers.dart] — this is what makes it overridable with a
/// test double built on `firebase_auth_mocks`.
@Riverpod(keepAlive: true)
Raw<AuthSessionNotifier> authSessionNotifier(Ref ref) => AuthSessionNotifier.instance;

/// Monotonic revision counter, incremented every time the underlying
/// [AuthSessionNotifier] fires. There is no richer state to expose (see
/// above) — consumers that need the actual user still read it from
/// `ProfileSession`/`profileService`, this only tells them *when* to
/// re-check.
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
