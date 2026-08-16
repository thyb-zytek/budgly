import 'dart:async';

import 'package:budgly/src/core/auth/google_sign_in.dart';
import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/services/accounts.dart';
import 'providers/supabase/user_profiles.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
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

  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final UserProfileSupabase _userProfileSupabase = UserProfileSupabase();

  AuthService._();

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
      String message = e.code == 'requires-recent-login' ? e.message! : "An error occurred while changing password";
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
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (userCredential.user == null) {
        throw const AuthenticationException(code: 'user-creation-failed', message: 'Failed to create user');
      }

      await userCredential.user!.sendEmailVerification();
      UserProfile profile = await _userProfileSupabase.getOrCreateProfile(userCredential.user!);

      return User.fromFirebaseUser(userCredential.user!, profile: profile);
    } catch (e) {
      if (e is fb.FirebaseAuthException && e.code == 'email-already-in-use') {
        throw const AuthenticationException(code: 'email-already-in-use', message: 'Email already in use');
      }
      throw AuthenticationException(code: 'sign-up-failed', message: 'Failed to sign up: $e');
    }
  }

  Future<User> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final fbUser = userCredential.user;
      if (fbUser == null) {
        throw const AuthenticationException(code: 'user-not-found', message: 'No user found');
      }

      final UserProfile profile;
      if (fbUser.emailVerified) {
        final results = await Future.wait([
          _userProfileSupabase.getOrCreateProfile(fbUser),
          AccountsService.instance.loadAccounts(),
        ]);
        profile = results[0] as UserProfile;
      } else {
        profile = await _userProfileSupabase.getOrCreateProfile(fbUser);
      }

      return User.fromFirebaseUser(fbUser, profile: profile);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(code: e.code, message: e.message ?? "An error occurred during sign in");
    } catch (e) {
      throw AuthenticationException(code: 'sign-in-failed', message: 'Failed to sign in: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(code: e.code, message: e.message ?? "An error occurred");
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final fb.User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(code: e.code, message: e.message ?? "An error occurred");
    }
  }

  Future<User> signInWithGoogle() async {
    try {
      await GoogleSignInInitializer.ensureInitialized();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      final fbUser = userCredential.user!;

      final results = await Future.wait([
        _userProfileSupabase.getOrCreateProfile(fbUser),
        AccountsService.instance.loadAccounts(),
      ]);
      final profile = results[0] as UserProfile;

      return User.fromFirebaseUser(fbUser, profile: profile);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(code: e.code, message: e.message ?? 'Google Sign-In Error');
    } catch (e) {
      if (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthenticationException(code: 'canceled', message: 'Google Sign-In was canceled.');
      }
      throw AuthenticationException(code: 'google-sign-in-failed', message: 'Failed to sign in with Google: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw AuthenticationException(code: 'sign-out-failed', message: 'Failed to sign out: $e');
    }
  }
}