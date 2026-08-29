import 'package:budgly/src/core/auth/google_sign_in.dart';
import 'package:budgly/src/core/auth/auth_exception.dart';
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
  static AuthService? _instance;

  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  final fb.FirebaseAuth? _authInput;
  final GoogleSignIn? _googleSignInInput;
  final UserProfileSupabase _userProfileSupabase;

  fb.FirebaseAuth get _auth => _authInput ?? fb.FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn =>
      _googleSignInInput ?? GoogleSignIn.instance;

  AuthService({
    fb.FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UserProfileSupabase? userProfileSupabase,
  })  : _authInput = auth,
        _googleSignInInput = googleSignIn,
        _userProfileSupabase = userProfileSupabase ?? UserProfileSupabase();

  AuthService._() : this();

  User? get currentUser =>
      _auth.currentUser != null ? User.fromFirebaseUser(_auth.currentUser!) : null;

  Future<User> changePassword(String oldPassword, String newPassword) async {
    try {
      final fb.User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw const AuthenticationException(code: 'no-user', message: 'No user is currently signed in');
      }
      if (firebaseUser.providerData.any((provider) => provider.providerId == 'google.com')) {
        throw const AuthenticationException(code: 'google-user', message: 'Cannot change password for Google users');
      }
      await firebaseUser.reauthenticateWithCredential(
        fb.EmailAuthProvider.credential(email: firebaseUser.email!, password: oldPassword),
      );
      await firebaseUser.updatePassword(newPassword);
      await firebaseUser.reload();

      UserProfile profile = await _userProfileSupabase.getOrCreateProfile(firebaseUser);
      return User.fromFirebaseUser(firebaseUser, profile: profile);
    } on fb.FirebaseAuthException catch (e) {
      String message = e.code == 'requires-recent-login'
          ? (e.message ?? 'Recent login required')
          : "An error occurred while changing password";
      throw AuthenticationException(code: e.code, message: message);
    } catch (e) {
      throw AuthenticationException(code: 'password-change-failed', message: 'Failed to change password: $e');
    }
  }

  Future<void> onChangeName(String name) async {
    final fb.User? firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw const AuthenticationException(code: 'no-user', message: 'No user is currently signed in');
    }
    await _userProfileSupabase.updateProfile(firebaseUser.uid, {"full_name": name});
  }

  Future<User?> reloadCurrentUser() async {
    try {
      final fb.User? user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        UserProfile profile = await _userProfileSupabase.getOrCreateProfile(user);
        return User.fromFirebaseUser(user, profile: profile);
      }
      return null;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(code: e.code, message: e.message ?? "An error occurred");
    } catch (e) {
      throw AuthenticationException(code: 'reload-failed', message: 'Failed to reload user: $e');
    }
  }

  Future<User> signUpWithEmailAndPassword(String email, String password) async {
    AnalyticsService.instance.track('signup_started');
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (userCredential.user == null) {
        throw const AuthenticationException(code: 'user-creation-failed', message: 'Failed to create user');
      }

      await userCredential.user!.sendEmailVerification();
      UserProfile profile = await _userProfileSupabase.getOrCreateProfile(userCredential.user!);

      final user = User.fromFirebaseUser(userCredential.user!, profile: profile);
      await AnalyticsService.instance.identify(user.id);
      AnalyticsService.instance.track('signup_completed');
      return user;
    } catch (e) {
      if (e is fb.FirebaseAuthException && e.code == 'email-already-in-use') {
        throw const AuthenticationException(code: 'email-already-in-use', message: 'Email already in use');
      }
      AnalyticsService.instance.track('signup_failed', {'error_code': e is fb.FirebaseAuthException ? e.code : 'unknown'});
      throw AuthenticationException(code: 'sign-up-failed', message: 'Failed to sign up: $e');
    }
  }

  Future<User> signInWithEmailAndPassword(String email, String password) async {
    AnalyticsService.instance.track('login_started');
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final fbUser = userCredential.user;
      if (fbUser == null) {
        throw const AuthenticationException(code: 'user-not-found', message: 'No user found');
      }

      final UserProfile profile =
          await _userProfileSupabase.getOrCreateProfile(fbUser);
      final user = User.fromFirebaseUser(fbUser, profile: profile);
      await AnalyticsService.instance.identify(user.id);
      AnalyticsService.instance.track('login_completed');
      return user;
    } on fb.FirebaseAuthException catch (e) {
      AnalyticsService.instance.track('login_failed', {'error_code': e.code});
      throw AuthenticationException(code: e.code, message: e.message ?? "An error occurred during sign in");
    } catch (e) {
      throw AuthenticationException(code: 'sign-in-failed', message: 'Failed to sign in: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    AnalyticsService.instance.track('password_reset_started');
    try {
      await _auth.sendPasswordResetEmail(email: email);
      AnalyticsService.instance.track('password_reset_completed');
    } on fb.FirebaseAuthException catch (e) {
      AnalyticsService.instance.track('password_reset_failed', {'error_code': e.code});
      throw AuthenticationException(code: e.code, message: e.message ?? "An error occurred");
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final fb.User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        AnalyticsService.instance.track('email_verification_sent');
      }
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(code: e.code, message: e.message ?? "An error occurred");
    }
  }

  Future<User> signInWithGoogle() async {
    AnalyticsService.instance.track('google_signin_started');
    try {
      await GoogleSignInInitializer.ensureInitialized();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw const AuthenticationException(
          code: 'missing-id-token',
          message: 'Google Sign-In did not return an ID token. '
              'Check Firebase SHA / serverClientId configuration.',
        );
      }
      final credential = fb.GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      final fbUser = userCredential.user;
      if (fbUser == null) {
        throw const AuthenticationException(
          code: 'no-firebase-user',
          message: 'Firebase did not return a user after Google credential.',
        );
      }

      final profile = await _userProfileSupabase.getOrCreateProfile(fbUser);
      final user = User.fromFirebaseUser(fbUser, profile: profile);
      await AnalyticsService.instance.identify(user.id);
      AnalyticsService.instance.track('google_signin_completed');
      return user;
    } on fb.FirebaseAuthException catch (e) {
      AnalyticsService.instance.track('google_signin_failed', {'error_code': e.code});
      throw AuthenticationException(code: e.code, message: e.message ?? 'Google Sign-In Error');
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthenticationException(code: 'canceled', message: 'Google Sign-In was canceled.');
      }
      AnalyticsService.instance.track('google_signin_failed', {'error_code': e.code.name});
      throw AuthenticationException(code: e.code.name, message: e.toString());
    } catch (e) {
      if (e is AuthenticationException) rethrow;
      AnalyticsService.instance.track('google_signin_failed', {'error_code': 'unknown'});
      throw AuthenticationException(code: 'google-sign-in-failed', message: 'Failed to sign in with Google: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      await AnalyticsService.instance.reset();
      AnalyticsService.instance.track('logout_completed');
    } catch (e) {
      AnalyticsService.instance.track('logout_failed');
      throw AuthenticationException(code: 'sign-out-failed', message: 'Failed to sign out: $e');
    }
  }
}
