import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Owns the single process-wide initialization of [GoogleSignIn].
///
/// On Android the "Sign in with Google" flow runs through Credential Manager,
/// which requires the **Web** OAuth client ID (`client_type: 3`) of the
/// Firebase project as `serverClientId`. Without it the platform returns no
/// ID token and `signInWithCredential` fails, so the value is resolved from
/// `assets/.env` and validated eagerly instead of being hardcoded in Dart.
class GoogleSignInInitializer {
  /// Key holding the Web OAuth client ID in `assets/.env`.
  static const serverClientIdKey = 'GOOGLE_SERVER_CLIENT_ID';

  static Future<void>? _future;

  /// Reads and validates [serverClientIdKey] from an environment map.
  ///
  /// Throws a [StateError] when the key is absent or blank: silently
  /// initializing with an empty value would only fail later, at the first
  /// credential exchange.
  static String readServerClientId(Map<String, String> env) {
    final value = env[serverClientIdKey]?.trim();
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing $serverClientIdKey. Expected the Web OAuth client ID '
        '(client_type 3) of the Firebase project, as found in '
        'google-services.json under oauth_client.',
      );
    }
    return value;
  }

  /// Reads the Web OAuth client ID from the loaded `assets/.env`.
  static String resolveServerClientId() {
    if (!dotenv.isInitialized) {
      throw StateError(
        'dotenv is not loaded: $serverClientIdKey must be read after '
        'dotenv.load().',
      );
    }
    return readServerClientId(dotenv.env);
  }

  /// Initializes [GoogleSignIn] once per process, memoizing the future.
  static Future<void> ensureInitialized() => _future ??= _initialize();

  static Future<void> _initialize() async {
    final serverClientId = resolveServerClientId();
    debugPrint('[google_sign_in] initialize serverClientId=$serverClientId');
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
  }

  static void reinitializeForTest({Future<void>? future}) {
    _future = future;
  }
}
