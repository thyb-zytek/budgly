import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Notifies [GoRouter] when Firebase auth state changes.
class AuthSessionNotifier extends ChangeNotifier {
  static final AuthSessionNotifier instance = AuthSessionNotifier._();

  AuthSessionNotifier._() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }
}
