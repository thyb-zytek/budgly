import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

class EntityForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final Widget leadingWidget;
  final TextEditingController nameController;
  final String labelText;
  final String? Function(String?)? validator;
  final void Function(String)? onTextChange;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final bool denseButtons;
  final FocusNode? focusNode;

  const EntityForm({
    super.key,
    required this.formKey,
    required this.leadingWidget,
    required this.nameController,
    required this.labelText,
    this.validator,
    this.onTextChange,
    required this.onSubmit,
    required this.onCancel,
    this.denseButtons = true,
    this.focusNode,
  });

  void _onSubmit() {
    if (formKey.currentState!.validate()) {
      onSubmit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Row(
            spacing: 8,
            children: [
              leadingWidget,
              Expanded(
                child: TextInput(
                  focusNode: focusNode,
                  controller: nameController,
                  labelText: labelText,
                  onChange: onTextChange,
                  hotValidating: validator ?? (v) => v == null || v.trim().isEmpty ? tr.nameRequired : null,
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ),
          Row(
            spacing: 16,
            children: [
              Expanded(
                child: FilledButton(
                  style: ButtonType.error.filledStyle(theme, dense: denseButtons),
                  onPressed: onCancel,
                  child: Text(
                    tr.cancel,
                    style: ButtonType.error.labelStyle(theme, dense: denseButtons),
                  ),
                ),
              ),
              Expanded(
                child: FilledButton(
                  style: ButtonType.primary.filledStyle(theme, dense: denseButtons),
                  onPressed: _onSubmit,
                  child: Text(
                    tr.validate,
                    style: ButtonType.primary.labelStyle(theme, dense: denseButtons),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}