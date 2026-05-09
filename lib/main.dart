import 'package:app/firebase_options.dart';
import 'package:app/src/app.dart';
import 'package:app/src/core/routers/base.dart';
import 'package:app/src/services/preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env");
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_KEY'];

  if (supabaseUrl == null || supabaseKey == null) {
    throw Exception('Missing Supabase environment variables');
  }

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/saira/OFL.txt');
    yield LicenseEntryWithLineBreaks(['assets/fonts/saira/'], license);
  });

  await GoogleSignIn.instance.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    accessToken: () async {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      return token;
    },
  );

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null || !refreshedUser.emailVerified) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      await FirebaseAuth.instance.signOut();
    }
  }

  await PreferencesService.init();
  NavigationHelper.instance;

  runApp(const BudglyApp());
}
