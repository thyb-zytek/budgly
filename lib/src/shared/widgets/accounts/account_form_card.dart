import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/accounts/avatar.dart';
import 'package:app/src/shared/widgets/accounts/avatar_picker.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:app/src/shared/widgets/buttons/icon_button.dart';
import 'package:app/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

import 'constants.dart';

class AccountFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final AccountEditingData editingData;
  final Future<String?> Function() pickImage;
  final Function(Color) onChangeColor;
  final Function(String?) onChangePicture;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onRemovePicture;

  const AccountFormCard({
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

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4).copyWith(right: 8),
        child: Form(
          key: formKey,
          child: Row(
            spacing: 4,
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
                    onTap:
                        () => showDialog(
                          context: context,
                          builder:
                              (context) => AvatarPicker(
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
              ),
              Expanded(
                child: TextInput(
                  controller: editingData.nameController,
                  labelText: tr.accountName,
                  hotValidating:
                      (v) =>
                          v == null || v.isEmpty
                              ? tr.accountNameRequired
                              : null,
                  textInputAction: TextInputAction.done,
                ),
              ),
              BudglyIconButton(
                icon: Icons.check_circle_rounded,
                type: ButtonType.success,
                onPressed: _onSubmit,
                smallIcon: true,
              ),
              BudglyIconButton(
                icon: Icons.cancel_rounded,
                type: ButtonType.error,
                onPressed: onCancel,
                smallIcon: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
