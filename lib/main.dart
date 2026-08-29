import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/auth/google_sign_in.dart';
import 'src/services/analytics/analytics_service.dart';
import 'src/services/offline/sync_manager.dart';
import 'src/services/profile/profile_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/saira/OFL.txt');
    yield LicenseEntryWithLineBreaks(['assets/fonts/saira/'], license);
  });

  await Future.wait([
    dotenv.load(fileName: 'assets/.env'),
    Firebase.initializeApp(),
  ]);

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_KEY'];
  if (supabaseUrl == null || supabaseKey == null) {
    throw Exception('Missing Supabase environment variables');
  }

  await Future.wait([
    _initializeCrashlytics(),
    ProfileService.instance.init(),
    Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      accessToken: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return null;
        return user.getIdToken();
      },
    ),
  ]);

  runApp(const BudglyApp());

  SyncManager.instance.start();
  unawaited(ProfileService.instance.refreshUserProfileInBackground());
  unawaited(GoogleSignInInitializer.ensureInitialized());
  unawaited(_initializeAnalytics());
}

Future<void> _initializeAnalytics() async {
  final posthogKey = dotenv.env['POSTHOG_API_KEY'];
  if (posthogKey != null && posthogKey.trim().isNotEmpty) {
    await AnalyticsService.instance.initialize(
      projectToken: posthogKey,
      host: dotenv.env['POSTHOG_HOST'] ?? 'https://eu.i.posthog.com',
    );
  }
  AnalyticsService.instance.track('app_started');

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await AnalyticsService.instance.identify(user.uid);
  }
}

Future<void> _initializeCrashlytics() async {
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final isOverflow = details.toString().contains('RenderFlex overflowed');
    if (!isOverflow) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
    previousOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      fatal: true,
    );
    return true;
  };
}

