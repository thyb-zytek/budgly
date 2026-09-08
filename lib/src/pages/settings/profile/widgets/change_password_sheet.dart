import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/pages/settings/profile/view_model.dart';
import 'package:budgly/src/shared/ui/widgets/forms/form_actions.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class ChangePasswordSheet extends StatefulWidget {
  final ProfileViewModel viewModel;
  final VoidCallback onSubmit;

  const ChangePasswordSheet({
    super.key,
    required this.viewModel,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required ProfileViewModel viewModel,
    required VoidCallback onSubmit,
  }) {
    return showAppBottomSheet(
      context,
      builder: (_) => ChangePasswordSheet(
        viewModel: viewModel,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (isValid) widget.onSubmit();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final vm = widget.viewModel;

    String? Function(String?) hotValidate(String mismatchKey) {
      return (v) {
        final result = vm.validatePassword(v);
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
              padding: const EdgeInsets.symmetric(horizontal: BudglySpacing.xl),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    spacing: 8,
                    children: [
                      TextInput(
                        controller: vm.oldPasswordController,
                        labelText: tr.oldPassword,
                        type: InputType.password,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
                        hotValidating: (v) =>
                            v?.isEmpty ?? true ? tr.passwordRequired : null,
                      ),
                      TextInput(
                        controller: vm.passwordController,
                        labelText: tr.password,
                        type: InputType.password,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
                        hotValidating: hotValidate('passwordTooShort'),
                      ),
                      TextInput(
                        controller: vm.confirmPasswordController,
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
              padding: const EdgeInsets.symmetric(horizontal: BudglySpacing.xl),
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
