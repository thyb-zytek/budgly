import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/pages/settings/profile/profile_settings_provider.dart';
import 'package:budgly/src/shared/ui/widgets/forms/form_actions.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

typedef ChangePasswordCallback =
    void Function(String oldPassword, String newPassword);

class ChangePasswordSheet extends StatefulWidget {
  final ChangePasswordCallback onSubmit;

  const ChangePasswordSheet({super.key, required this.onSubmit});

  static Future<void> show(
    BuildContext context, {
    required ChangePasswordCallback onSubmit,
  }) {
    return showAppBottomSheet(
      context,
      builder: (_) => ChangePasswordSheet(onSubmit: onSubmit),
    );
  }

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    widget.onSubmit(_oldPasswordController.text, _passwordController.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    String? Function(String?) hotValidate(String mismatchKey) {
      return (v) {
        final result = validatePassword(v, _passwordController.text);
        if (result == 'passwordRequired') return tr.passwordRequired;
        if (result == mismatchKey) {
          return mismatchKey == 'passwordTooShort'
              ? tr.passwordTooShort
              : tr.passwordsDontMatch;
        }
        return result;
      };
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 24,
          children: [
            Text(
              tr.editPassword,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: BudglySpacing.xl),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    spacing: 8,
                    children: [
                      TextInput(
                        controller: _oldPasswordController,
                        labelText: tr.oldPassword,
                        type: InputType.password,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
                        hotValidating: (v) =>
                            v?.isEmpty ?? true ? tr.passwordRequired : null,
                      ),
                      TextInput(
                        controller: _passwordController,
                        labelText: tr.password,
                        type: InputType.password,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
                        hotValidating: hotValidate('passwordTooShort'),
                      ),
                      TextInput(
                        controller: _confirmPasswordController,
                        labelText: tr.confirmPassword,
                        type: InputType.password,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        hotValidating: hotValidate('passwordsDoNotMatch'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: BudglySpacing.xl),
              child: FormActions(
                destructiveCancel: true,
                dense: true,
                onCancel: () => Navigator.pop(context),
                onSubmit: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
