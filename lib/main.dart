import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/auth/google_sign_in.dart';
import 'src/services/analytics/analytics_service.dart';
import 'src/services/analytics/analytics_service_provider.dart';
import 'src/services/offline/sync_bootstrap_provider.dart';
import 'src/services/offline/sync_manager_provider.dart';

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

  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BudglyStartup(),
    ),
  );
}

class BudglyStartup extends StatefulWidget {
  const BudglyStartup({super.key});

  @override
  State<BudglyStartup> createState() => _BudglyStartupState();
}

class _BudglyStartupState extends State<BudglyStartup> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(syncBootstrapProvider);
      container.read(syncManagerProvider).start();
      unawaited(_initializeCrashlytics());
      unawaited(_initializeAnalytics(container.read(analyticsServiceProvider)));
      unawaited(GoogleSignInInitializer.ensureInitialized());
    });
  }

  @override
  Widget build(BuildContext context) => const BudglyApp();
}

Future<void> _initializeAnalytics(AnalyticsService analytics) async {
  final posthogKey = dotenv.env['POSTHOG_API_KEY'];
  if (posthogKey != null && posthogKey.trim().isNotEmpty) {
    await analytics.initialize(
      projectToken: posthogKey,
      host: dotenv.env['POSTHOG_HOST'] ?? 'https://eu.i.posthog.com',
    );
  }
  analytics.track('app_started');

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await analytics.identify(user.uid);
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
    FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
    return true;
  };
}
