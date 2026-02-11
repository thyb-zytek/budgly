import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/inputs/input.dart';
import 'package:app/src/shared/widgets/inputs/constants.dart';

class ChangePasswordForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController oldPasswordController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final String? Function(String?) validatePassword;
  final Function() onSubmit;

  ChangePasswordForm({
    super.key,
    required this.formKey,
    required this.oldPasswordController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.validatePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr.editPassword,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: AutofillGroup(
                child: Form(
                  key: formKey,
                  child: Column(
                    spacing: 8,
                    children: [
                      TextInput(
                        controller: oldPasswordController,
                        labelText: tr.oldPassword,
                        type: InputType.password,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted:
                            (_) => FocusScope.of(context).nextFocus(),
                        hotValidating: (v) {
                          if (v?.isEmpty ?? true) {
                            return tr.passwordRequired;
                          } else {
                            return null;
                          }
                        },
                      ),
                      TextInput(
                        controller: passwordController,
                        labelText: tr.password,
                        type: InputType.password,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted:
                            (_) => FocusScope.of(context).nextFocus(),
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
                        controller: confirmPasswordController,
                        labelText: tr.confirmPassword,
                        type: InputType.password,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          onSubmit();
                          Navigator.pop(context);
                        },
                        hotValidating: (v) {
                          String? result = validatePassword(v);
                          if (result == "passwordRequired") {
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
            ),
            Padding(
              padding: const EdgeInsets.all(16).copyWith(top: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BudglyButton(
                    text: tr.cancel,
                    type: ButtonType.error,
                    dense: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                  BudglyButton(
                    text: tr.validate,
                    type: ButtonType.primary,
                    dense: true,
                    onPressed: () {
                      onSubmit();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
