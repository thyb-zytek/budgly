import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthSessionNotifier extends ChangeNotifier {
  static final AuthSessionNotifier instance = AuthSessionNotifier._();

  late final StreamSubscription<User?> _subscription;

  AuthSessionNotifier._() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
