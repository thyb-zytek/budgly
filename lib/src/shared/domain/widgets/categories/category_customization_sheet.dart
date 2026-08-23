import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/shared/ui/widgets/customization_picker.dart';
import 'package:budgly/src/shared/ui/widgets/layout/color_wheel.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:budgly/src/shared/ui/widgets/tabs/tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';

typedef CategoryPreviewBuilder = Widget Function(
  BuildContext context,
  CategoryIcon icon,
  Color color,
);

Future<bool> showCategoryCustomizationSheet(
  BuildContext context, {
  required List<CategoryIcon> availableIcons,
  required CategoryIcon initialIcon,
  required Color initialColor,
  required CategoryPreviewBuilder previewBuilder,
  required ValueChanged<CategoryIcon> onIconChanged,
  required ValueChanged<Color> onColorChanged,
}) {
  final tr = AppLocalizations.of(context)!;
  final searchController = TextEditingController();

  var selectedIcon = initialIcon;
  var selectedColor = initialColor;
  var filteredIcons = availableIcons;

  void selectIcon(CategoryIcon icon) {
    selectedIcon = icon;
    onIconChanged(icon);
  }

  void filterIcons(String query) {
    final locale = tr.localeName;
    filteredIcons = availableIcons.where((icon) {
      final label = icon.labels[locale] ?? icon.iconName;
      return label.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  return showAppBottomSheet(
    context,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: CustomizationPicker(
                title: tr.categoryCustomization,
                previewWidget:
                    previewBuilder(context, selectedIcon, selectedColor),
                tabTitles: [
                  TabTitle(icon: Icons.category_rounded, title: tr.icon),
                  TabTitle(icon: Icons.palette_rounded, title: tr.color),
                ],
                tabs: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: [
                      TextInput(
                        controller: searchController,
                        labelText: tr.searchIcon,
                        onChange: (query) => setModalState(
                          () => filterIcons(query),
                        ),
                        onFieldSubmitted: (_) {
                          if (filteredIcons.isNotEmpty) {
                            setModalState(
                              () => selectIcon(filteredIcons.first),
                            );
                          }
                        },
                      ),
                      SizedBox(
                        height: 220,
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 1,
                          ),
                          itemCount: filteredIcons.length,
                          itemBuilder: (context, index) => _IconGridTile(
                            icon: filteredIcons[index],
                            isSelected: selectedIcon.iconName ==
                                filteredIcons[index].iconName,
                            onTap: () =>
                                setModalState(() => selectIcon(filteredIcons[index])),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ColorWheel(
                    key: const ValueKey('category_color_wheel'),
                    color: selectedColor,
                    onChanged: (color) => setModalState(() {
                      selectedColor = color;
                      onColorChanged(color);
                    }),
                  ),
                ],
                onValidate: () => Navigator.pop(sheetContext, true),
                onCancel: () => Navigator.pop(sheetContext, false),
              ),
            ),
          );
        },
      );
    },
  ).then((result) {
    searchController.dispose();
    return result ?? false;
  });
}

class _IconGridTile extends StatelessWidget {
  final CategoryIcon icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconGridTile({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Icon(
          IconPickerIcon(
            name: icon.iconName,
            data: icon.toIconData(),
            pack: icon.iconPack,
          ).data,
          size: 32,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
