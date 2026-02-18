import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:app/src/shared/widgets/buttons/icon_button.dart';
import 'package:app/src/shared/widgets/categories/constants.dart';
import 'package:app/src/shared/widgets/categories/icon.dart';
import 'package:app/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';
import 'package:app/src/models/category/category_icon.dart' as cim;

class CategoryFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<cim.CategoryIcon> availableIcons;
  final CategoryEditingData editingData;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final ValueChanged<Color> onChangeColor;
  final ValueChanged<cim.CategoryIcon> onChangeIcon;

  const CategoryFormCard({
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
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ).copyWith(right: 8),
        child: Form(
          key: formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12.0, right: 8.0),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: editingData.nameController,
                  builder: (context, value, child) {
                    return CategoryIcon(
                      availableIcons: availableIcons,
                      icon: editingData.icon,
                      color: editingData.color,
                      onChangeColor: onChangeColor,
                      onChangeIcon: onChangeIcon,
                    );
                  },
                ),
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
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  spacing: 4,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
            ],
          ),
        ),
      ),
    );
  }
}
