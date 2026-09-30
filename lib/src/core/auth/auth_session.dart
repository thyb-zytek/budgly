import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Listenable bridge for Firebase Auth state changes.
///
/// Ownership is handled by Riverpod; this class deliberately has no global
/// singleton so tests and application scopes can provide their own Firebase
/// Auth instance and lifecycle.
class AuthSessionNotifier extends ChangeNotifier {
  late final StreamSubscription<User?> _subscription;

  AuthSessionNotifier({FirebaseAuth? auth}) {
    _subscription = (auth ?? FirebaseAuth.instance).authStateChanges().listen((
      _,
    ) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
