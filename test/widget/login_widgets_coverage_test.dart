import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:budgly/src/pages/login/widgets/google_sign_in_button.dart';
import 'package:budgly/src/pages/login/widgets/login_appbar.dart';
import 'package:budgly/src/pages/login/widgets/login_form.dart';
import 'package:budgly/src/pages/login/widgets/login_loading_page.dart';
import 'package:budgly/src/pages/login/widgets/reset_password_form.dart';
import 'package:budgly/src/pages/login/widgets/signup_form.dart';
import 'package:budgly/src/pages/login/widgets/verify_email.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('Google sign-in button renders and invokes callback', (tester) async {
    var calls = 0;
    await pumpApp(tester, GoogleSignInButton(onPressed: () => calls++));
    expect(find.text('Se connecter avec Google'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Se connecter avec Google'));
    expect(calls, 1);
  });

  testWidgets('login appbar covers regular and compact layouts', (tester) async {
    await pumpApp(
      tester,
      const Column(children: [LoginAppbar(), LoginAppbar(isCompact: true)]),
      size: const Size(700, 740),
    );
    expect(find.text('Budgly'), findsNWidgets(2));
    expect(find.text('Gérer votre budget en toute simplicité.'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('login form exposes error messages and actions', (tester) async {
    final email = TextEditingController();
    final password = TextEditingController();
    addTearDown(email.dispose);
    addTearDown(password.dispose);
    var reset = 0;
    var submit = 0;
    var signUp = 0;

    await pumpApp(tester, LoginForm(
      formKey: GlobalKey<FormState>(),
      emailController: email,
      passwordController: password,
      validateEmail: (value) {
        if (value == null || value.isEmpty) return 'emailRequired';
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'emailInvalid';
        return null;
      },
      validatePassword: (value) =>
          value == null || value.isEmpty ? 'passwordRequired' : null,
      errorCode: 'emailRequired',
      onResetPassword: () => reset++,
      onSubmitForm: () => submit++,
      onSignUpPressed: () => signUp++,
    ));

    expect(find.text('Veuillez fournir une adresse mail.'), findsOneWidget);
    await tester.tap(find.text('Reinitialiser le mot de passe'));
    await tester.tap(find.text('S\'inscrire'));
    await tester.tap(find.text('Se connecter'));
    expect(reset, 1);
    expect(signUp, 1);
    expect(submit, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpApp(tester, LoginForm(
      formKey: GlobalKey<FormState>(),
      emailController: email,
      passwordController: password,
      validateEmail: (value) {
        if (value == null || value.isEmpty) return 'emailRequired';
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'emailInvalid';
        return null;
      },
      validatePassword: (value) =>
          value == null || value.isEmpty ? 'passwordRequired' : null,
      errorCode: 'passwordRequired',
      onResetPassword: () {},
      onSubmitForm: () {},
      onSignUpPressed: () {},
    ));
    expect(find.text('Veuillez fournir un mot de passe.'), findsOneWidget);
  });

  testWidgets('reset password form renders and exposes both actions', (tester) async {
    final email = TextEditingController();
    addTearDown(email.dispose);
    var submit = 0;
    var signIn = 0;
    await pumpApp(tester, ResetPasswordForm(
      formKey: GlobalKey<FormState>(),
      emailController: email,
      validateEmail: (value) {
        if (value == null || value.isEmpty) return 'emailRequired';
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'emailInvalid';
        return null;
      },
      onSubmitForm: () => submit++,
      onSignInPressed: () => signIn++,
    ));
    expect(find.textContaining('adresse mail'), findsOneWidget);
    await tester.tap(find.text('Envoyer le mail'));
    await tester.tap(find.text('Se connecter'));
    expect(submit, 1);
    expect(signIn, 1);
  });

  testWidgets('sign-up form renders fields and actions', (tester) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final password2 = TextEditingController();
    addTearDown(email.dispose);
    addTearDown(password.dispose);
    addTearDown(password2.dispose);
    var submit = 0;
    var signIn = 0;
    await pumpApp(tester, SignUpForm(
      formKey: GlobalKey<FormState>(),
      emailController: email,
      passwordController: password,
      password2Controller: password2,
      validateEmail: (value) {
        if (value == null || value.isEmpty) return 'emailRequired';
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'emailInvalid';
        return null;
      },
      validatePassword: (value) =>
          value == null || value.isEmpty ? 'passwordRequired' : null,
      validateConfirmPassword: (value) => value == password.text ? null : 'invalid',
      onSubmitForm: () => submit++,
      onSignInPressed: () => signIn++,
    ));
    expect(find.text('Adresse mail'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Confirmer le mot de passe'), findsOneWidget);
    await tester.tap(find.text('S\'inscrire'));
    await tester.tap(find.text('Se connecter'));
    expect(submit, 1);
    expect(signIn, 1);
  });

  testWidgets('loading page selects each authentication message', (tester) async {
    for (final form in AuthForm.values) {
      await pumpApp(tester, LoginLoadingView(formType: form, isGoogleSignIn: false), settle: false);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    }
    await pumpApp(tester, const LoginLoadingView(formType: AuthForm.signIn, isGoogleSignIn: true), settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Google'), findsOneWidget);
  });

  testWidgets('verify email exposes resend and sign-in actions', (tester) async {
    var resend = 0;
    var signIn = 0;
    var reload = 0;
    await pumpApp(tester, VerifyEmail(
      email: 'alexis@example.com',
      onSignInPressed: () => signIn++,
      onResendPressed: () => resend++,
      onReload: () => reload++,
    ));
    expect(find.textContaining('alexis@example.com'), findsOneWidget);
    await tester.tap(find.text('Renvoyer l\'email de vérification'));
    await tester.tap(find.text('Se connecter'));
    expect(resend, 1);
    expect(signIn, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(reload, 1);
  });
}
