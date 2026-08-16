import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

class ResetPasswordForm extends StatelessWidget {
  final Key formKey;
  final TextEditingController emailController;
  final String? Function(String?) validateEmail;

  final VoidCallback onSubmitForm;
  final VoidCallback onSignInPressed;

  ResetPasswordForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.validateEmail,
    required this.onSubmitForm,
    required this.onSignInPressed,
  });

  String? _translateEmailError(AppLocalizations tr, String? code) {
    return switch (code) {
      'emailRequired' => tr.emailRequired,
      'emailInvalid' => tr.emailInvalid,
      _ => code,
    };
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations tr = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AutofillGroup(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 40,
              children: [
                Text(
                  tr.askEmailForResetPassword,
                  style: theme.textTheme.bodyMedium,
                ),
                TextInput(
                  type: InputType.email,
                  controller: emailController,
                  labelText: tr.email,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onSubmitForm(),
                  hotValidating: (v) => _translateEmailError(tr, validateEmail(v)),
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
          padding: EdgeInsets.only(top: 24),
          child: FilledButton(
            style: ButtonType.primary.filledStyle(theme),
            onPressed: onSubmitForm,
            child: Text(
              tr.sendEmail,
              style: ButtonType.primary.labelStyle(theme),
            ),
          ),
        ),
      ],
    );
  }
}