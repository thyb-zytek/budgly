import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthSessionNotifier extends ChangeNotifier {
  static AuthSessionNotifier? _instance;

  static AuthSessionNotifier get instance =>
      _instance ??= AuthSessionNotifier._default();

  late final StreamSubscription<User?> _subscription;

  AuthSessionNotifier._default() : this();

  AuthSessionNotifier({FirebaseAuth? auth}) {
    _subscription = (auth ?? FirebaseAuth.instance).authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
