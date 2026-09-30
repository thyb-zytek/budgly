import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'login_provider.g.dart';

enum AuthDestination { overview, tutorial }

String? validateLoginEmail(String? value) {
  if (value == null || value.isEmpty) return 'emailRequired';
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'emailInvalid';
  return null;
}

String? validateLoginPassword(String? value) {
  if (value == null || value.isEmpty) return 'passwordRequired';
  if (value.length < 6) return 'passwordTooShort';
  return null;
}

String? validateLoginConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) return 'confirmPasswordRequired';
  if (value != password) return 'passwordsDoNotMatch';
  return null;
}

@riverpod
class Login extends _$Login {
  static const _hasLaunchedKey = 'hasLaunched';

  @override
  AuthState build() {
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser != null && !currentUser.emailVerified) {
      return AuthState(
        currentUser: currentUser,
        formType: AuthForm.verifyEmail,
      );
    }
    return AuthState(formType: AuthForm.signIn);
  }

  Future<void> initializeFormType() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final hasLaunched = prefs.getBool(_hasLaunchedKey) ?? false;
    changeFormType(hasLaunched ? AuthForm.signIn : AuthForm.signUp);
    if (!hasLaunched) await prefs.setBool(_hasLaunchedKey, true);
  }

  void changeFormType(AuthForm formType) {
    state = state.copyWith(
      formType: formType,
      errorCode: null,
      errorMessage: null,
      isLoading: false,
      isGoogleSignIn: false,
    );
  }

  /// RL-01 §2: `UserProfile.onboardingCompleted` is the only input of the
  /// post-authentication decision.
  ///
  /// A completed onboarding bypasses the tutorial and lands on the Overview,
  /// even when the user currently owns no account (they may have deleted them
  /// all). Anything else — flag `false` or a profile that is not available —
  /// enters the onboarding flow, which resumes at the persisted step.
  Future<AuthDestination> resolvePostAuthDestination(User user) async {
    return user.profile?.onboardingCompleted == true
        ? AuthDestination.overview
        : AuthDestination.tutorial;
  }

  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    return _runAuthentication(() async {
      final user = await ref
          .read(authServiceProvider)
          .signInWithEmailAndPassword(email, password);
      if (!user.emailVerified) {
        if (!ref.mounted) return null;
        state = state.copyWith(
          isLoading: false,
          currentUser: user,
          formType: AuthForm.verifyEmail,
          isGoogleSignIn: false,
        );
        return null;
      }
      await ref.read(profileSessionProvider.notifier).load(forceRefresh: true);
      await _waitForProfileLoaded();
      if (!ref.mounted) return null;
      state = state.copyWith(
        isLoading: false,
        currentUser: user,
        isGoogleSignIn: false,
      );
      return user;
    });
  }

  Future<User?> signUp({
    required String email,
    required String password,
  }) async {
    return _runAuthentication(() async {
      final user = await ref
          .read(authServiceProvider)
          .signUpWithEmailAndPassword(email, password);
      await ref.read(profileSessionProvider.notifier).load(forceRefresh: true);
      await _waitForProfileLoaded();
      if (!ref.mounted) return null;
      state = state.copyWith(
        isLoading: false,
        currentUser: user,
        formType: AuthForm.verifyEmail,
        isGoogleSignIn: false,
      );
      return null;
    });
  }

  Future<User?> signInWithGoogle() async {
    return _runAuthentication(() async {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      await ref.read(profileSessionProvider.notifier).load(forceRefresh: true);
      await _waitForProfileLoaded();
      if (!ref.mounted) return null;
      state = state.copyWith(
        isLoading: false,
        currentUser: user,
        isGoogleSignIn: false,
      );
      return user;
    }, google: true);
  }

  Future<void> _waitForProfileLoaded() async {
    const maxAttempts = 50;
    for (var i = 0; i < maxAttempts; i++) {
      if (!ref.mounted) return;
      final session = ref.read(profileSessionProvider);
      if (session.hasLoaded && session.currentUser != null) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(
      isLoading: true,
      errorCode: null,
      errorMessage: null,
      isGoogleSignIn: false,
    );
    try {
      await ref.read(authServiceProvider).resetPassword(email);
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, formType: AuthForm.signIn);
    } on AuthenticationException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: e.code,
        errorMessage: e.message,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: 'unknownError',
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> reloadUser() async {
    try {
      final user = await ref.read(authServiceProvider).reloadCurrentUser();
      if (!ref.mounted) return;
      if (user != null && user.emailVerified) {
        await ref
            .read(profileSessionProvider.notifier)
            .load(forceRefresh: true);
        await _waitForProfileLoaded();
        if (!ref.mounted) return;
        state = state.copyWith(
          isLoading: false,
          currentUser: user,
          isGoogleSignIn: false,
        );
      } else {
        state = state.copyWith(
          currentUser: user,
          isLoading: false,
          isGoogleSignIn: false,
        );
      }
    } on AuthenticationException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: e.code,
        errorMessage: e.message,
        isGoogleSignIn: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: 'reloadError',
        errorMessage: e.toString(),
        isGoogleSignIn: false,
      );
    }
  }

  Future<void> resendEmailVerification() async {
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
    } on AuthenticationException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: e.code,
        errorMessage: e.message,
        isGoogleSignIn: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: 'unknownError',
        errorMessage: e.toString(),
        isGoogleSignIn: false,
      );
    }
  }

  Future<void> signOut() async {
    try {
      await ref.read(profileSessionProvider.notifier).signOut();
      if (!ref.mounted) return;
      state = state.copyWith(
        currentUser: null,
        formType: state.formType == AuthForm.resetPassword
            ? AuthForm.signIn
            : AuthForm.signUp,
        isLoading: false,
        errorCode: null,
        errorMessage: null,
        isGoogleSignIn: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: 'signOutError',
        errorMessage: e.toString(),
        isGoogleSignIn: false,
      );
    }
  }

  Future<User?> _runAuthentication(
    Future<User?> Function() action, {
    bool google = false,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorCode: null,
      errorMessage: null,
      isGoogleSignIn: google,
    );
    try {
      return await action();
    } on AuthenticationException catch (e) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        isLoading: false,
        formType: google ? AuthForm.signIn : null,
        errorCode: e.code,
        errorMessage: e.message,
        isGoogleSignIn: false,
      );
    } catch (e) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        isLoading: false,
        formType: google ? AuthForm.signIn : null,
        errorCode: google ? 'googleSignInError' : 'unknownError',
        errorMessage: e.toString(),
        isGoogleSignIn: false,
      );
    }
    return null;
  }
}
