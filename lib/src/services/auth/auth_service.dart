import 'package:budgly/src/core/auth/google_sign_in.dart';
import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/services/providers/supabase/user_profiles.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show
        GoogleSignIn,
        GoogleSignInAccount,
        GoogleSignInAuthentication,
        GoogleSignInException,
        GoogleSignInExceptionCode;

class AuthService {
  final fb.FirebaseAuth? _authInput;
  final GoogleSignIn? _googleSignInInput;
  final UserProfileSupabase _userProfileSupabase;
  final AnalyticsService _analytics;

  fb.FirebaseAuth get _auth => _authInput ?? fb.FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => _googleSignInInput ?? GoogleSignIn.instance;

  AuthService({
    fb.FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UserProfileSupabase? userProfileSupabase,
    required this._analytics,
  }) : _authInput = auth,
       _googleSignInInput = googleSignIn,
       _userProfileSupabase = userProfileSupabase ?? UserProfileSupabase();

  User? get currentUser => _auth.currentUser != null
      ? User.fromFirebaseUser(_auth.currentUser!)
      : null;

  /// The raw Firebase auth session backing this service. Useful for services
  /// that need the user id without going through the domain mapping, and for
  /// tests injecting a [MockFirebaseAuth].
  fb.User? get firebaseUser => _auth.currentUser;

  /// Raw Firebase Auth state stream. Riverpod-owned consumers use this to
  /// react to external sign-out/session changes without introducing a second
  /// mutable auth state holder.
  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();

  Future<User> changePassword(String oldPassword, String newPassword) async {
    try {
      final fb.User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw const AuthenticationException(
          code: 'no-user',
          message: 'No user is currently signed in',
        );
      }
      if (firebaseUser.providerData.any(
        (provider) => provider.providerId == 'google.com',
      )) {
        throw const AuthenticationException(
          code: 'google-user',
          message: 'Cannot change password for Google users',
        );
      }
      await firebaseUser.reauthenticateWithCredential(
        fb.EmailAuthProvider.credential(
          email: firebaseUser.email!,
          password: oldPassword,
        ),
      );
      await firebaseUser.updatePassword(newPassword);
      await firebaseUser.reload();

      UserProfile profile = await _userProfileSupabase.getOrCreateProfile(
        firebaseUser,
      );
      return User.fromFirebaseUser(firebaseUser, profile: profile);
    } on fb.FirebaseAuthException catch (e) {
      String message = e.code == 'requires-recent-login'
          ? (e.message ?? 'Recent login required')
          : "An error occurred while changing password";
      throw AuthenticationException(code: e.code, message: message);
    } catch (e) {
      throw AuthenticationException(
        code: 'password-change-failed',
        message: 'Failed to change password: $e',
      );
    }
  }

  Future<void> onChangeName(String name) async {
    final fb.User? firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw const AuthenticationException(
        code: 'no-user',
        message: 'No user is currently signed in',
      );
    }
    await _userProfileSupabase.updateProfile(firebaseUser.uid, {
      "full_name": name,
    });
  }

  Future<User?> reloadCurrentUser() async {
    try {
      final fb.User? user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        UserProfile profile = await _userProfileSupabase.getOrCreateProfile(
          user,
        );
        return User.fromFirebaseUser(user, profile: profile);
      }
      return null;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? "An error occurred",
      );
    } catch (e) {
      throw AuthenticationException(
        code: 'reload-failed',
        message: 'Failed to reload user: $e',
      );
    }
  }

  Future<User> signUpWithEmailAndPassword(String email, String password) async {
    AppLogger.info('auth.email.signup: Firebase account creation started');
    _analytics.track('signup_started');
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user == null) {
        throw const AuthenticationException(
          code: 'user-creation-failed',
          message: 'Failed to create user',
        );
      }

      await userCredential.user!.sendEmailVerification();
      AppLogger.info('auth.email.signup: verification email request completed');
      AppLogger.info('auth.email.signup: profile lookup started');
      UserProfile profile = await _userProfileSupabase.getOrCreateProfile(
        userCredential.user!,
      );
      AppLogger.info('auth.email.signup: profile lookup completed');

      final user = User.fromFirebaseUser(
        userCredential.user!,
        profile: profile,
      );
      AppLogger.info('auth.email.signup: analytics identity update started');
      await _analytics.identify(user.id);
      AppLogger.info('auth.email.signup: analytics identity update completed');
      _analytics.track('signup_completed');
      AppLogger.info('auth.email.signup: completed');
      return user;
    } catch (e) {
      AppLogger.error(
        'auth.email.signup: failed '
        '(code=${e is fb.FirebaseAuthException ? e.code : 'unknown'})',
        e,
      );
      if (e is fb.FirebaseAuthException && e.code == 'email-already-in-use') {
        throw const AuthenticationException(
          code: 'email-already-in-use',
          message: 'Email already in use',
        );
      }
      _analytics.track('signup_failed', {
        'error_code': e is fb.FirebaseAuthException ? e.code : 'unknown',
      });
      throw AuthenticationException(
        code: 'sign-up-failed',
        message: 'Failed to sign up: $e',
      );
    }
  }

  Future<User> signInWithEmailAndPassword(String email, String password) async {
    AppLogger.info('auth.email.signin: Firebase authentication started');
    _analytics.track('login_started');
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = userCredential.user;
      AppLogger.info(
        'auth.email.signin: Firebase authentication completed '
        '(userPresent=${fbUser != null})',
      );
      if (fbUser == null) {
        throw const AuthenticationException(
          code: 'user-not-found',
          message: 'No user found',
        );
      }

      AppLogger.info('auth.email.signin: Supabase profile lookup started');
      final UserProfile profile = await _userProfileSupabase.getOrCreateProfile(
        fbUser,
      );
      AppLogger.info('auth.email.signin: Supabase profile lookup completed');
      final user = User.fromFirebaseUser(fbUser, profile: profile);
      AppLogger.info('auth.email.signin: analytics identity update started');
      await _analytics.identify(user.id);
      AppLogger.info('auth.email.signin: analytics identity update completed');
      _analytics.track('login_completed');
      AppLogger.info('auth.email.signin: completed');
      return user;
    } on fb.FirebaseAuthException catch (e) {
      AppLogger.error(
        'auth.email.signin: Firebase rejected credentials (code=${e.code})',
        e,
      );
      _analytics.track('login_failed', {'error_code': e.code});
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? "An error occurred during sign in",
      );
    } catch (e) {
      AppLogger.error(
        'auth.email.signin: failed after authentication attempt',
        e,
      );
      throw AuthenticationException(
        code: 'sign-in-failed',
        message: 'Failed to sign in: $e',
      );
    }
  }

  Future<void> resetPassword(String email) async {
    _analytics.track('password_reset_started');
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _analytics.track('password_reset_completed');
    } on fb.FirebaseAuthException catch (e) {
      _analytics.track('password_reset_failed', {'error_code': e.code});
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? "An error occurred",
      );
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final fb.User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _analytics.track('email_verification_sent');
      }
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? "An error occurred",
      );
    }
  }

  Future<User> signInWithGoogle() async {
    AppLogger.info('auth.google.signin: flow started');
    _analytics.track('google_signin_started');
    try {
      AppLogger.info('auth.google.signin: ensuring SDK initialization');
      await GoogleSignInInitializer.ensureInitialized();

      AppLogger.info('auth.google.signin: waiting for account selection');
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      AppLogger.info('auth.google.signin: account selected');
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      AppLogger.info(
        'auth.google.signin: ID token available='
        '${googleAuth.idToken != null && googleAuth.idToken!.isNotEmpty}',
      );
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw const AuthenticationException(
          code: 'missing-id-token',
          message:
              'Google Sign-In did not return an ID token. '
              'Check Firebase SHA / serverClientId configuration.',
        );
      }
      final credential = fb.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final fbUser = userCredential.user;
      AppLogger.info(
        'auth.google.signin: Firebase credential exchange completed '
        '(userPresent=${fbUser != null})',
      );
      if (fbUser == null) {
        throw const AuthenticationException(
          code: 'no-firebase-user',
          message: 'Firebase did not return a user after Google credential.',
        );
      }

      AppLogger.info('auth.google.signin: Supabase profile lookup started');
      final profile = await _userProfileSupabase.getOrCreateProfile(fbUser);
      AppLogger.info('auth.google.signin: Supabase profile lookup completed');
      final user = User.fromFirebaseUser(fbUser, profile: profile);
      AppLogger.info('auth.google.signin: analytics identity update started');
      await _analytics.identify(user.id);
      AppLogger.info('auth.google.signin: analytics identity update completed');
      _analytics.track('google_signin_completed');
      AppLogger.info('auth.google.signin: flow completed');
      return user;
    } on fb.FirebaseAuthException catch (e) {
      AppLogger.error(
        'auth.google.signin: Firebase rejected credential (code=${e.code})',
        e,
      );
      _analytics.track('google_signin_failed', {'error_code': e.code});
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? 'Google Sign-In Error',
      );
    } on GoogleSignInException catch (e) {
      // `code` alone is not actionable: the Android Credential Manager also
      // reports configuration failures (unregistered signing SHA-1, wrong
      // package name, wrong serverClientId) as `canceled` after the account
      // chooser, so the platform description must be logged too.
      AppLogger.error(
        'auth.google.signin: Google SDK failed '
        '(code=${e.code.name}, description=${e.description})',
        e,
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthenticationException(
          code: 'canceled',
          message: 'Google Sign-In was canceled.',
        );
      }
      _analytics.track('google_signin_failed', {'error_code': e.code.name});
      throw AuthenticationException(code: e.code.name, message: e.toString());
    } catch (e) {
      AppLogger.error('auth.google.signin: flow failed', e);
      _analytics.track('google_signin_failed', {'error_code': e.toString()});
      if (e is AuthenticationException) rethrow;
      throw AuthenticationException(
        code: 'google-sign-in-failed',
        message: 'Failed to sign in with Google: $e',
      );
    }
  }

  Future<void> signOut() async {
    try {
      // Use signOut() to clear the current session. This keeps the account
      // in the Google Sign-In account list so the user can re-authenticate
      // without going through the full consent flow again. Use disconnect()
      // only for explicit account unlinking.
      await _googleSignIn.signOut();
      await _auth.signOut();
      await _analytics.reset();
      _analytics.track('logout_completed');
    } catch (e) {
      _analytics.track('logout_failed');
      throw AuthenticationException(
        code: 'sign-out-failed',
        message: 'Failed to sign out: $e',
      );
    }
  }
}
