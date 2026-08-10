import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/shared/widgets/avatar/avatar.dart';
import 'package:budgly/src/shared/widgets/accounts/avatar_picker.dart';
import 'package:budgly/src/shared/widgets/buttons/button.dart';
import 'package:budgly/src/shared/widgets/buttons/constants.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

import 'package:budgly/src/shared/widgets/accounts/constants.dart';

class AccountForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final AccountEditingData editingData;
  final Future<String?> Function() pickImage;
  final Function(Color) onChangeColor;
  final Function(String?) onChangePicture;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onRemovePicture;

  const AccountForm({
    super.key,
    required this.formKey,
    required this.editingData,
    required this.pickImage,
    required this.onChangeColor,
    required this.onChangePicture,
    required this.onSubmit,
    required this.onCancel,
    this.onRemovePicture,
  });

  void _onSubmit() {
    if (formKey.currentState!.validate()) {
      onSubmit();
    }
  }

  void _openAvatarPicker(BuildContext context, String initial) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: AvatarPicker(
              color: editingData.color,
              picture: editingData.picture,
              initial: initial,
              onChangeColor: onChangeColor,
              pickImage: pickImage,
              onChangePicture: onChangePicture,
              onRemovePicture: onRemovePicture,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Row(
            spacing: 12,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: editingData.nameController,
                builder: (context, value, child) {
                  final initial = value.text.isNotEmpty ? value.text[0] : 'A';
                  return Avatar(
                    initial: initial.toUpperCase(),
                    backgroundColor: editingData.color,
                    picture: editingData.picture,
                    isLocalPicture: editingData.isLocalPicture,
                    size: 52,
                    onTap: () => _openAvatarPicker(context, initial),
                  );
                },
              ),
              Expanded(
                child: TextInput(
                  controller: editingData.nameController,
                  labelText: tr.accountName,
                  hotValidating:
                      (v) => v == null || v.isEmpty ? tr.nameRequired : null,
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ),
          // Action buttons
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: BudglyButton(
                  onPressed: onCancel,
                  type: ButtonType.error,
                  text: tr.cancel,
                  dense: true,
                ),
              ),
              Expanded(
                child: BudglyButton(
                  onPressed: _onSubmit,
                  type: ButtonType.primary,
                  text: tr.validate,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}