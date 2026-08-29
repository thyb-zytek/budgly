import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInInitializer {
  static Future<void>? _future;

  /// Web client ID (type 3) from google-services.json / Firebase console.
  /// Required on Android so [GoogleSignInAuthentication.idToken] is populated
  /// for Firebase credential exchange. Without it `idToken` stays null and
  /// `signInWithCredential` fails.
  static const _serverClientId =
      '630784587693-vvhh8tq961a6r1ui0vc9fgbsbmeq8n8m.apps.googleusercontent.com';

  static Future<void> ensureInitialized() {
    return _future ??= GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId,
    );
  }

  static void reinitializeForTest({Future<void>? future}) {
    _future = future;
  }
}
