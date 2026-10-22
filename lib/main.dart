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
import 'src/core/logging/logger.dart';
import 'src/services/analytics/analytics_service.dart';
import 'src/services/analytics/analytics_service_provider.dart';
import 'src/services/offline/sync_bootstrap_provider.dart';
import 'src/services/offline/sync_manager_provider.dart';

Future<void> main() async {
  AppLogger.info('startup: binding initialization started');
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/saira/OFL.txt');
    yield LicenseEntryWithLineBreaks(['assets/fonts/saira/'], license);
  });

  try {
    AppLogger.info('startup: loading app configuration and Firebase');
    await Future.wait([
      dotenv.load(fileName: 'assets/.env'),
      Firebase.initializeApp(),
    ]);
    AppLogger.info('startup: configuration and Firebase initialized');
  } catch (error, stackTrace) {
    AppLogger.error(
      'startup: configuration or Firebase initialization failed',
      error,
      stackTrace,
    );
    rethrow;
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_KEY'];
  if (supabaseUrl == null || supabaseKey == null) {
    AppLogger.error('startup: Supabase configuration is missing');
    throw Exception('Missing Supabase environment variables');
  }

  try {
    AppLogger.info('startup: initializing Supabase client');
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      accessToken: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          AppLogger.debug(
            'supabase auth token requested without Firebase user',
          );
          return null;
        }
        AppLogger.debug(
          'supabase auth token requested for authenticated session',
        );
        try {
          final token = await user.getIdToken();
          AppLogger.debug(
            'supabase auth token retrieval completed '
            '(tokenPresent=${token != null})',
          );
          return token;
        } catch (error, stackTrace) {
          AppLogger.error(
            'supabase auth token retrieval failed',
            error,
            stackTrace,
          );
          rethrow;
        }
      },
    );
    AppLogger.info('startup: Supabase initialized');
  } catch (error, stackTrace) {
    AppLogger.error(
      'startup: Supabase initialization failed',
      error,
      stackTrace,
    );
    rethrow;
  }

  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BudglyStartup(),
    ),
  );
  AppLogger.info('startup: first Flutter frame requested');
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
      AppLogger.info('startup: post-frame initialization started');
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(syncBootstrapProvider);
      container.read(syncManagerProvider).start();
      unawaited(_initializeCrashlytics());
      unawaited(_initializeAnalytics(container.read(analyticsServiceProvider)));
      unawaited(_initializeGoogleSignIn());
    });
  }

  @override
  Widget build(BuildContext context) => const BudglyApp();
}

Future<void> _initializeAnalytics(AnalyticsService analytics) async {
  AppLogger.info('startup: analytics initialization started');
  try {
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
    AppLogger.info('startup: analytics initialization completed');
  } catch (error, stackTrace) {
    AppLogger.error(
      'startup: analytics initialization failed',
      error,
      stackTrace,
    );
  }
}

Future<void> _initializeGoogleSignIn() async {
  try {
    AppLogger.info('startup: Google Sign-In initialization started');
    await GoogleSignInInitializer.ensureInitialized();
    AppLogger.info('startup: Google Sign-In initialization completed');
  } catch (error, stackTrace) {
    AppLogger.error(
      'startup: Google Sign-In initialization failed',
      error,
      stackTrace,
    );
  }
}

Future<void> _initializeCrashlytics() async {
  AppLogger.info('startup: Crashlytics initialization started');
  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final isOverflow = details.toString().contains('RenderFlex overflowed');
      if (isOverflow) {
        AppLogger.warning(
          'Flutter layout overflow: ${details.exceptionAsString()}',
        );
      } else {
        AppLogger.logOnlyError(
          'uncaught Flutter framework error '
          '(exceptionType=${details.exception.runtimeType})',
          details.exception,
          details.stack,
        );
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
      previousOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      AppLogger.logOnlyError('uncaught platform error', error, stackTrace);
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
      return true;
    };
    AppLogger.info(
      'startup: Crashlytics and global error handlers initialized',
    );
  } catch (error, stackTrace) {
    AppLogger.error(
      'startup: Crashlytics initialization failed',
      error,
      stackTrace,
    );
  }
}
