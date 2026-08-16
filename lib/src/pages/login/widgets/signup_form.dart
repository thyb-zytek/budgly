import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

class SignUpForm extends StatelessWidget {
  final Key formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController password2Controller;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;
  final String? Function(String?) validateConfirmPassword;

  final void Function() onSubmitForm;
  final void Function() onSignInPressed;

  SignUpForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.password2Controller,
    required this.validateEmail,
    required this.validatePassword,
    required this.validateConfirmPassword,
    required this.onSignInPressed,
    required this.onSubmitForm,
  });

  String? _translateEmailError(AppLocalizations tr, String? code) {
    return switch (code) {
      'emailRequired' => tr.emailRequired,
      'emailInvalid' => tr.emailInvalid,
      _ => code,
    };
  }

  String? _translatePasswordError(AppLocalizations tr, String? code) {
    return switch (code) {
      'passwordRequired' => tr.passwordRequired,
      'passwordTooShort' => tr.passwordTooShort,
      _ => code,
    };
  }

  String? _translateConfirmPasswordError(AppLocalizations tr, String? code) {
    return switch (code) {
      'confirmPasswordRequired' => tr.passwordRequired,
      'passwordsDoNotMatch' => tr.passwordsDontMatch,
      _ => code,
    };
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations tr = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AutofillGroup(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextInput(
                  type: InputType.email,
                  controller: emailController,
                  labelText: tr.email,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  hotValidating: (v) => _translateEmailError(tr, validateEmail(v)),
                ),
                TextInput(
                  controller: passwordController,
                  labelText: tr.password,
                  type: InputType.password,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  hotValidating: (v) => _translatePasswordError(tr, validatePassword(v)),
                ),
                TextInput(
                  controller: password2Controller,
                  labelText: tr.confirmPassword,
                  type: InputType.password,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onSubmitForm(),
                  hotValidating: (v) => _translateConfirmPasswordError(tr, validateConfirmPassword(v)),
                ),
              ],
            ),
          ),
        ),
        Row(
          spacing: 4,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(tr.userHasAccount),
            TextButton(
              onPressed: onSignInPressed,
              child: Text(
                tr.signIn,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).viewInsets.bottom > 0 ? 24 : 8),
          child: FilledButton(
            style: ButtonType.primary.filledStyle(theme),
            onPressed: onSubmitForm,
            child: Text(
              tr.signUp,
              style: ButtonType.primary.labelStyle(theme),
            ),
          ),
        ),
      ],
    );
  }
}