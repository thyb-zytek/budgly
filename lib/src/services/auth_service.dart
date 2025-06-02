import 'package:app/src/core/exceptions/auth_exceptions.dart';
import 'package:app/src/models/user/user.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final User? currentUser =
      fb.FirebaseAuth.instance.currentUser != null
          ? User.fromFirebaseUser(fb.FirebaseAuth.instance.currentUser!)
          : null;

  Future<User?> reloadCurrentUser() async {
    try {
      final fb.User? user = _auth.currentUser;
      if (user != null) {
        return await user.reload().then(
          (value) => User.fromFirebaseUser(_auth.currentUser!),
        );
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
      fb.UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      if (userCredential.user != null) {
        await userCredential.user!.sendEmailVerification();
      }
      return User.fromFirebaseUser(userCredential.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? "An error occurred",
      );
    }
  }

  Future<User> signInWithEmailAndPassword(String email, String password) async {
    try {
      fb.UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return User.fromFirebaseUser(userCredential.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthenticationException(
        code: e.code,
        message: e.message ?? "An error occurred",
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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthenticationException(
          code: 'sign-in-cancelled',
          message: 'Sign in was cancelled by user',
        );
      }

      final GoogleSignInAuthentication? googleAuth =
          await googleUser.authentication;
      if (googleAuth == null) {
        throw AuthenticationException(
          code: 'authentication-failed',
          message: 'Failed to get authentication data',
        );
      }

      final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      fb.UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      return User.fromFirebaseUser(userCredential.user!);
    } catch (e) {
      if (e is PlatformException) {
        throw AuthenticationException(
          code: e.code ?? 'unknown_error',
          message: e.message ?? 'An error occurred during Google Sign-In',
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
