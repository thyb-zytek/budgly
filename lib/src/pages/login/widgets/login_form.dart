import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:app/src/shared/widgets/inputs/constants.dart';
import 'package:app/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

class LoginForm extends StatelessWidget {
  final Key formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;

  final void Function() onResetPassword;
  final void Function() onSubmitForm;
  final void Function() onSignUpPressed;

  final String? errorCode;
  final String? errorMessage;

  LoginForm({
    super.key,
    required this.formKey,
    required this.onResetPassword,
    required this.emailController,
    required this.passwordController,
    required this.validateEmail,
    required this.validatePassword,
    this.errorCode,
    this.errorMessage,
    required this.onSubmitForm,
    required this.onSignUpPressed,
  });

  String _getErrorMessageText(BuildContext context) {
    switch (errorCode) {
      case "emailRequired":
        return AppLocalizations.of(context)!.emailRequired;
      case "passwordRequired":
        return AppLocalizations.of(context)!.passwordRequired;
      default:
        return errorMessage ?? "";
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    AppLocalizations tr = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AutofillGroup(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (errorCode != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _getErrorMessageText(context),
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                TextInput(
                  type: InputType.Username,
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
                  type: InputType.Password,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onSubmitForm(),
                  hotValidating: (v) {
                    String? result = validatePassword(v);
                    if (result == "passwordRequired") {
                      return tr.passwordRequired;
                    } else {
                      return result;
                    }
                  },
                ),
                TextButton(
                  onPressed: onResetPassword,
                  child: Text(
                    tr.resetPassword,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          spacing: 4,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(tr.userHasNoAccount),
            TextButton(
              onPressed: onSignUpPressed,
              child: Text(
                tr.signUp,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(top: 24),
          child: BudglyButton(text: tr.signIn, onPressed: onSubmitForm),
        ),
      ],
    );
  }
}
