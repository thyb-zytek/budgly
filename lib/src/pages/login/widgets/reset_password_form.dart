import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:app/src/shared/widgets/inputs/constants.dart';
import 'package:app/src/shared/widgets/inputs/input.dart';
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
                  type: InputType.username,
                  controller: emailController,
                  labelText: tr.email,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onSubmitForm(),
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
          child: BudglyButton(text: tr.sendEmail, onPressed: onSubmitForm),
        ),
      ],
    );
  }
}
