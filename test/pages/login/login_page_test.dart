import 'package:budgly/l10n/app_localizations.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(analytics: AnalyticsService());
  @override
  User? get currentUser => null;
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
  Future<User?> refreshFromServer() async => null;
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

Future<void> _pumpLoginPage(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
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
}
