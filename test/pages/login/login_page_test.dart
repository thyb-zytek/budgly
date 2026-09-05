import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/pages/login/view.dart';
import 'package:budgly/src/pages/login/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService extends AuthService {
  @override
  User? get currentUser => null;
}

class _NoopAccountsService extends AccountsService {}

Future<void> _pumpLoginPage(WidgetTester tester, LoginViewModel viewModel) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fr')],
      theme: ThemeData.light(useMaterial3: true),
      home: LoginPage(injectedViewModel: viewModel),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    // Keep initializeFormType() deterministic: without this, the fresh-
    // install path flips the form to sign-up shortly after mount.
    SharedPreferences.setMockInitialValues({'hasLaunched': true});
  });

  testWidgets('renders using the injected view model instead of creating its own', (
    tester,
  ) async {
    final viewModel = LoginViewModel(
      authService: _FakeAuthService(),
      profileService: ProfileService(),
      accountsService: _NoopAccountsService(),
    );

    await _pumpLoginPage(tester, viewModel);

    expect(
      find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller == viewModel.emailController,
      ),
      findsOneWidget,
    );

    viewModel.dispose();
  });

  testWidgets('unmounting the page does not dispose an injected view model', (
    tester,
  ) async {
    final viewModel = LoginViewModel(
      authService: _FakeAuthService(),
      profileService: ProfileService(),
      accountsService: _NoopAccountsService(),
    );

    await _pumpLoginPage(tester, viewModel);
    await tester.pumpWidget(const SizedBox.shrink());

    expect(viewModel.isDisposed, isFalse);

    viewModel.dispose();
  });
}
