import 'dart:io';

import 'package:app/src/core/exceptions/auth_exceptions.dart';
import 'package:app/src/models/user/user.dart';
import 'package:app/src/models/user/user_profile.dart';
import 'package:app/src/services/supabase_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final SupabaseService _supabaseService = SupabaseService();

  User? _currentUser;

  User? get currentUser => _currentUser;

  Future<User?> reloadCurrentUser() async {
    try {
      final fb.User? user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        UserProfile? profile = await _supabaseService.getUserProfile(user.uid);
        if (profile == null) {
          profile = UserProfile(
            id: user.uid,
            email: user.email!,
            fullName: user.displayName ?? user.email!.split('@').first,
          );
          profile = await _supabaseService.createProfile(user.uid, profile.toJson());
        }

        return User.fromFirebaseUser(user, profile: profile);
      } else {
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

      UserProfile? profile = await _supabaseService.getUserProfile(
        userCredential.user!.uid,
      );

      if (profile == null) {
        profile = UserProfile(
          id: userCredential.user!.uid,
          email: userCredential.user!.email ?? email,
          fullName:
              userCredential.user!.displayName ??
              userCredential.user!.email?.split('@').first ??
              email.split('@').first,
        );

        profile = await _supabaseService.createProfile(
          userCredential.user!.uid,
          profile.toJson(),
        );
      }

      final user = User.fromFirebaseUser(
        userCredential.user!,
        profile: profile,
      );

      print(
        'Utilisateur créé avec succès. Firebase UID: ${userCredential.user!.uid}, Supabase UUID: ${profile.id}',
      );

      _currentUser = user;
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? 'An error occurred during sign up',
      );
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
      final userId = userCredential.user!.uid;

      UserProfile? profile = await _supabaseService.getUserProfile(userId);

      if (profile == null) {
        profile = await _supabaseService.createProfile(
          userCredential.user!.uid,
          UserProfile(
            id: userCredential.user!.uid,
            email: userCredential.user!.email!,
            fullName:
                userCredential.user!.displayName ??
                userCredential.user!.email!.split('@').first,
          ).toJson(),
        );
      }
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
        throw AuthenticationException(
          code: 'google-signin-cancelled',
          message: 'Google Sign In was cancelled',
        );
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      UserProfile? profile = await _supabaseService.getUserProfile(
        userCredential.user!.uid,
      );

      if (profile == null) {
        profile = await _supabaseService.createProfile(
          userCredential.user!.uid,
          UserProfile(
            id: userCredential.user!.uid,
            email: userCredential.user!.email!,
            fullName: googleUser.displayName ??
                userCredential.user!.email!.split('@').first,
          ).toJson(),
        );
      }

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
