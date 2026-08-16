import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:flutter/material.dart';

class LoginLoadingView extends StatelessWidget {
  final AuthForm formType;
  final bool isGoogleSignIn;

  const LoginLoadingView({
    super.key,
    required this.formType,
    required this.isGoogleSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    final loadingMessage = isGoogleSignIn
        ? tr.googleSigningIn
        : switch (formType) {
            AuthForm.signIn => tr.signingIn,
            AuthForm.signUp => tr.signingUp,
            AuthForm.resetPassword => tr.resettingPassword,
            AuthForm.verifyEmail => tr.verifyingEmail,
          };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          Text(loadingMessage, style: theme.textTheme.titleMedium),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}