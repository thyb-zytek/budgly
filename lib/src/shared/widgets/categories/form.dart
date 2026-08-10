import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/shared/widgets/categories/constants.dart';
import 'package:budgly/src/shared/widgets/categories/icon.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';
import 'package:budgly/src/models/category/category_icon.dart' as cim;

class CategoryForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<cim.CategoryIcon> availableIcons;
  final CategoryEditingData editingData;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final ValueChanged<Color> onChangeColor;
  final ValueChanged<cim.CategoryIcon> onChangeIcon;

  const CategoryForm({
    super.key,
    required this.formKey,
    required this.availableIcons,
    required this.editingData,
    required this.onSubmit,
    required this.onCancel,
    required this.onChangeColor,
    required this.onChangeIcon,
  });

  void _onSubmit() {
    if (formKey.currentState?.validate() ?? false) {
      onSubmit();
    }
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
          // Icon and input on same row
          Row(
            spacing: 12,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: editingData.nameController,
                builder: (context, value, child) {
                  return CategoryIcon(
                    availableIcons: availableIcons,
                    icon: editingData.icon,
                    color: editingData.color,
                    onChangeColor: onChangeColor,
                    onChangeIcon: onChangeIcon,
                    size: 48,
                  );
                },
              ),
              Expanded(
                child: TextInput(
                  controller: editingData.nameController,
                  labelText: tr.categoryName,
                  onChange:
                      (v) =>
                          editingData.nameController.text =
                              '${v[0].toUpperCase()}${v.substring(1)}',
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
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: Text(tr.cancel),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: _onSubmit,
                  child: Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
