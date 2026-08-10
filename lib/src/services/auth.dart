import 'dart:async';

import 'package:budgly/src/core/exceptions/auth_exceptions.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'preferences.dart';
import 'supabase/user_profile_supabase.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart' show GoogleSignIn, GoogleSignInAccount, GoogleSignInAuthentication, GoogleSignInException, GoogleSignInExceptionCode;

class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final UserProfileSupabase _userProfileSupabase = UserProfileSupabase();

  User? _currentUser;

  User? get currentUser => _currentUser;

  Future<void> changePassword(String oldPassword, String newPassword) async {
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
      UserProfile profile = await _userProfileSupabase.getOrCreateProfile(firebaseUser);
      _currentUser = User.fromFirebaseUser(firebaseUser, profile: profile);
    } on fb.FirebaseAuthException catch (e) {
      String message = "An error occurred while changing password";

      if (e.code == 'requires-recent-login') {
        message = e.message!;
      }

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
    
    final changed = await _userProfileSupabase.updateProfile(
      firebaseUser.uid,
      {"full_name": name},
    );
    
    if (changed) {
      await reloadCurrentUser();
    }
  }

  Future<User?> reloadCurrentUser() async {
    try {
      final fb.User? user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        UserProfile profile = await _userProfileSupabase.getOrCreateProfile(user);

        await PreferencesService().setThemeModeFromString(profile.themeMode);

        final userObj = User.fromFirebaseUser(user, profile: profile);
        _currentUser = userObj;
        return userObj;
      } else {
        _currentUser = null;
        return null;
      }
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? "An error occurred",
      );
    } catch (e) {
      // Handle Supabase JWT errors gracefully
      if (e.toString().contains('JWT') || e.toString().contains('PGRST303')) {
        // Try to get cached user if available
        if (_currentUser != null) {
          return _currentUser;
        }
      }
      throw AuthenticationException(
        code: 'reload-failed',
        message: 'Failed to reload user: $e',
      );
    }
  }

  Future<User> signUpWithEmailAndPassword(String email, String password) async {
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

      UserProfile profile = await _userProfileSupabase.getOrCreateProfile(
        userCredential.user!,
      );
      final user = User.fromFirebaseUser(
        userCredential.user!,
        profile: profile,
      );
      _currentUser = user;
      return user;
    } catch (e) {
      if (e is fb.FirebaseAuthException && e.code == 'email-already-in-use') {
        // Email already in use, but we want to throw a specific error
        throw AuthenticationException(
          code: 'email-already-in-use',
          message: 'Email already in use',
        );
      }
      throw AuthenticationException(
        code: 'sign-up-failed',
        message: 'Failed to sign up: $e',
      );
    }
  }

  Future<User> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw AuthenticationException(
          code: 'user-not-found',
          message: 'No user found for that email and password',
        );
      }
      UserProfile profile = await _userProfileSupabase.getOrCreateProfile(
        userCredential.user!,
      );

      await Future.wait([
        PreferencesService().setThemeModeFromString(profile.themeMode),
        PreferencesService().setLocale(Locale(profile.language)),
        PreferencesService().setCurrency(profile.currency),
      ]);

      final user = User.fromFirebaseUser(
        userCredential.user!,
        profile: profile,
      );

      _currentUser = user;

      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? "An error occurred during sign in",
      );
    } catch (e) {
      throw AuthenticationException(
        code: 'sign-in-failed',
        message: 'Failed to sign in: $e',
      );
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
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
      }
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? "An error occurred",
      );
    }
  }

  Future<User> signInWithGoogle() async {
    try {
      // Clear any existing Google sign-in state first
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      final credential = fb.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      UserProfile profile = await _userProfileSupabase.getOrCreateProfile(
        userCredential.user!,
      );

      await Future.wait([
        PreferencesService().setThemeModeFromString(profile.themeMode),
        PreferencesService().setLocale(Locale(profile.language)),
        PreferencesService().setCurrency(profile.currency),
      ]);

      final user = User.fromFirebaseUser(
        userCredential.user!,
        profile: profile,
      );

      _currentUser = user;
      return user;
    } on fb.FirebaseAuthException catch (e) {
      // Handle specific Firebase auth errors
      if (e.code == 'account-exists-with-different-credential') {
        throw AuthenticationException(
          code: 'account-exists-with-different-credential',
          message: 'An account already exists with a different credential. Please sign in with the correct method.',
        );
      }
      if (e.code == 'invalid-credential') {
        throw AuthenticationException(
          code: 'invalid-credential',
          message: 'The credential is invalid or has expired.',
        );
      }
      if (e.code == 'user-disabled') {
        throw AuthenticationException(
          code: 'user-disabled',
          message: 'This user account has been disabled.',
        );
      }
      if (e.code == 'invalid-email') {
        throw AuthenticationException(
          code: 'invalid-email',
          message: 'The email address is badly formatted.',
        );
      }
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? 'An error occurred during Google Sign-In',
      );
    } catch (e) {
      if (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthenticationException(
          code: 'canceled',
          message: 'Google Sign-In was canceled.',
        );
      }
      throw AuthenticationException(
        code: 'google-sign-in-failed',
        message: 'Failed to sign in with Google: $e',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      _currentUser = null;
    } catch (e) {
      throw AuthenticationException(
        code: 'sign-out-failed',
        message: 'Failed to sign out: $e',
      );
    }
  }
}