import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:app/src/shared/widgets/inputs/constants.dart';
import 'package:app/src/shared/widgets/inputs/input.dart';
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
                  type: InputType.username,
                  controller: emailController,
                  labelText: tr.email,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  hotValidating: (v) {
                    String? result = validateEmail(v);
                    if (result == "emailRequired") {
                      return tr.emailRequired;
                    } else if (result == "emailRequired") {
                      return tr.emailRequired;
                    } else {
                      return result;
                    }
                  },
                ),
                TextInput(
                  controller: passwordController,
                  labelText: tr.password,
                  type: InputType.password,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  hotValidating: (v) {
                    String? result = validatePassword(v);
                    if (result == "passwordRequired") {
                      return tr.passwordRequired;
                    } else if (result == "passwordTooShort") {
                      return tr.passwordTooShort;
                    } else {
                      return result;
                    }
                  },
                ),
                TextInput(
                  controller: password2Controller,
                  labelText: tr.confirmPassword,
                  type: InputType.password,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onSubmitForm(),
                  hotValidating: (v) {
                    String? result = validateConfirmPassword(v);
                    if (result == "confirmPasswordRequired") {
                      return tr.passwordRequired;
                    } else if (result == "passwordsDoNotMatch") {
                      return tr.passwordsDontMatch;
                    } else {
                      return result;
                    }
                  },
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
          child: BudglyButton(text: tr.signUp, onPressed: onSubmitForm),
        ),
      ],
    );
  }
}
