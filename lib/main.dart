import 'dart:async';

import 'package:budgly/src/core/auth/google_sign_in.dart';

import 'src/app.dart';
import 'src/core/auth/auth_session.dart';
import 'src/core/routers/navigation_helper.dart';
import 'src/services/profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/saira/OFL.txt');
    yield LicenseEntryWithLineBreaks(['assets/fonts/saira/'], license);
  });

  await Future.wait([
    dotenv.load(fileName: "assets/.env"),
    Firebase.initializeApp(),
  ]);

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_KEY'];
  if (supabaseUrl == null || supabaseKey == null) {
    throw Exception('Missing Supabase environment variables');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    accessToken: () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return user.getIdToken();
    },
  );

  await Future.wait([
    _restoreSession(),
    ProfileService.instance.init(),
  ]);

  AuthSessionNotifier.instance;
  NavigationHelper.instance;

  runApp(const BudglyApp());
  unawaited(GoogleSignInInitializer.ensureInitialized());
}

Future<void> _restoreSession() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    await user.reload();
  } on FirebaseAuthException catch (e) {
    const invalidatingCodes = {
      'user-disabled',
      'user-not-found',
      'user-token-expired',
      'invalid-user-token',
    };
    if (invalidatingCodes.contains(e.code)) {
      await FirebaseAuth.instance.signOut();
      return;
    }
    await _hydrateProfile();
    return;
  } catch (_) {
    await _hydrateProfile();
    return;
  }

  final refreshedUser = FirebaseAuth.instance.currentUser;
  if (refreshedUser == null) return;

  if (!refreshedUser.emailVerified) {
    await FirebaseAuth.instance.signOut();
    return;
  }

  await _hydrateProfile();
}
Future<void> _hydrateProfile() async {
  try {
    await ProfileService.instance.loadUserProfile();
  } catch (_) {
    print("Failed to load user profile");
  }
}