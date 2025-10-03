import 'package:app/firebase_options.dart';
import 'package:app/src/app.dart';
import 'package:app/src/core/routers/base.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/src/services/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env");

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/saira/OFL.txt');
    yield LicenseEntryWithLineBreaks(['assets/fonts/saira/'], license);
  });

  await Future.wait([
    GoogleSignIn.instance.initialize(),
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_KEY']!,
      authOptions: FlutterAuthClientOptions(detectSessionInUri: false),
      accessToken: () async {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        return token;
      },
    ),
  ]);

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null || !refreshedUser.emailVerified) {
        await FirebaseAuth.instance.signOut();
      }
    }
  } catch (e) {
    await FirebaseAuth.instance.signOut();
  }

  await PreferencesService.init();

  NavigationHelper.instance;

  runApp(const BudglyApp());
}
