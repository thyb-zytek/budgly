import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInInitializer {
  static Future<void>? _future;

  static Future<void> ensureInitialized() {
    return _future ??= GoogleSignIn.instance.initialize();
  }
}