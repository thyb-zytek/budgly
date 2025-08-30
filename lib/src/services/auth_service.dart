import 'dart:async';
import 'dart:io';

import 'package:app/src/core/exceptions/auth_exceptions.dart';
import 'package:app/src/models/user/user.dart';
import 'package:app/src/models/user/user_profile.dart';
import 'package:app/src/services/preferences_service.dart';
import 'package:app/src/services/supabase_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final SupabaseService _supabaseService = SupabaseService();

  User? _currentUser;

  User? get currentUser {
    if ((_auth.currentUser != null && _auth.currentUser != _currentUser) ||
        (_currentUser != null && !_currentUser!.hasProfile)) {
      _supabaseService.getOrCreateProfile(_auth.currentUser!).then((profile) {
        _currentUser = User.fromFirebaseUser(
          _auth.currentUser!,
          profile: profile,
        );
      });
    }
    return _currentUser;
  }

  Future<User?> reloadCurrentUser() async {
    try {
      final fb.User? user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        UserProfile profile = await _supabaseService.getOrCreateProfile(user);

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

      UserProfile profile = await _supabaseService.getOrCreateProfile(
        userCredential.user!,
      );
      final user = User.fromFirebaseUser(
        userCredential.user!,
        profile: profile,
      );
      _currentUser = user;
      return user;
    } catch (e) {
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
      UserProfile profile = await _supabaseService.getOrCreateProfile(
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
      await _googleSignIn.signOut();

      GoogleSignInAccount? googleUser;
      googleUser = await _googleSignIn.attemptLightweightAuthentication();
      if (googleUser == null) {
        googleUser = await _googleSignIn.authenticate();
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      UserProfile profile = await _supabaseService.getOrCreateProfile(
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
        message: e.message ?? 'An error occurred during Google Sign-In',
      );
    } on SocketException catch (e) {
      throw AuthenticationException(
        code: 'network-error',
        message: 'Network error during Google Sign-In: ${e.message}',
      );
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') {
        throw AuthenticationException(
          code: 'google-signin-cancelled',
          message: 'Google Sign In was cancelled',
        );
      }
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? 'An error occurred during Google Sign-In',
      );
    } catch (e) {
      throw AuthenticationException(
        code: 'google-signin-failed',
        message: 'Failed to sign in with Google: $e',
      );
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
