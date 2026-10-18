import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/pages/login/view.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({this.signedInUser}) : super(analytics: AnalyticsService());

  final User? signedInUser;
  Object? resendError;
  int resendCalls = 0;

  @override
  User? get currentUser => null;

  @override
  fb.User? get firebaseUser => null;

  @override
  Stream<fb.User?> get authStateChanges => const Stream<fb.User?>.empty();

  @override
  Future<User> signInWithEmailAndPassword(String email, String password) async {
    return signedInUser!;
  }

  @override
  Future<void> sendEmailVerification() async {
    resendCalls++;
    if (resendError != null) throw resendError!;
  }
}

class _FakeProfileService extends ProfileService {
  _FakeProfileService()
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );
  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async => null;

  @override
  Future<User?> refreshFromServer({bool rethrowErrors = false}) async => null;
}

class _FakeAccountsService extends AccountsService {
  _FakeAccountsService()
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );
}

Future<void> _pumpLoginPage(
  WidgetTester tester, {
  _FakeAuthService? auth,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth ?? _FakeAuthService()),
        profileServiceProvider.overrideWithValue(_FakeProfileService()),
        accountsServiceProvider.overrideWithValue(_FakeAccountsService()),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('fr')],
        theme: ThemeData.light(useMaterial3: true),
        home: const LoginPage(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'hasLaunched': true}));

  testWidgets('renders the login form from the Riverpod state', (tester) async {
    await _pumpLoginPage(tester);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('uses the provider state when the form changes', (tester) async {
    await _pumpLoginPage(tester);
    await tester.ensureVisible(find.text("S'inscrire"));
    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets(
    'a resend cooldown shows a clear message that disappears once the email '
    'is actually sent',
    (tester) async {
      const user = User(
        id: 'u1',
        email: 'alexis@example.com',
        emailVerified: false,
      );
      final auth = _FakeAuthService(signedInUser: user);
      await _pumpLoginPage(tester, auth: auth);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'alexis@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.ensureVisible(find.text('Se connecter'));
      await tester.tap(find.text('Se connecter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The unverified sign-in lands on the email-verification step.
      expect(find.text('Renvoyer l\'email de vérification'), findsOneWidget);

      auth.resendError = const AuthenticationException(
        code: 'too-many-requests',
        message: 'We have blocked all requests from this device.',
      );
      await tester.ensureVisible(
        find.text('Renvoyer l\'email de vérification'),
      );
      await tester.tap(find.text('Renvoyer l\'email de vérification'));
      await tester.pump();
      expect(
        find.text(
          'Un email de vérification a déjà été envoyé. Veuillez patienter '
          'quelques instants avant d\'en demander un nouveau.',
        ),
        findsOneWidget,
      );

      auth.resendError = null;
      await tester.ensureVisible(
        find.text('Renvoyer l\'email de vérification'),
      );
      await tester.tap(find.text('Renvoyer l\'email de vérification'));
      await tester.pump();
      expect(find.textContaining('déjà été envoyé'), findsNothing);
      expect(auth.resendCalls, 2);
    },
  );
}
