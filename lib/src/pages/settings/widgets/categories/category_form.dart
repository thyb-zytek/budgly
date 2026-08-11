import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart' as cim;
import 'package:budgly/src/pages/settings/widgets/categories/view_model.dart';
import 'package:budgly/src/pages/settings/widgets/customization_picker.dart';
import 'package:budgly/src/pages/settings/widgets/entity_form.dart';
import 'package:budgly/src/shared/widgets/categories/icon.dart';
import 'package:budgly/src/shared/widgets/inputs/color_wheel.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:budgly/src/shared/widgets/tabs/tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';

class CategoryForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final CategoriesViewModel viewModel;
  final Category? category;

  const CategoryForm({
    super.key,
    required this.formKey,
    required this.viewModel,
    this.category,
  });

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  late cim.CategoryIcon _tempIcon;
  late Color _tempColor;
  late final FocusNode _nameFocusNode;

  @override
  void initState() {
    super.initState();
    _tempIcon = widget.viewModel.editingData.icon;
    _tempColor = widget.viewModel.editingData.color;
    _nameFocusNode = FocusNode();

    if (widget.category?.id == null) {
      Future.delayed(const Duration(milliseconds: 300), () => _nameFocusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _openCustomizationPicker(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final searchController = TextEditingController();
    List<cim.CategoryIcon> filteredIcons = widget.viewModel.editingData.availableIcons;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterIcons(String query) {
              final locale = tr.localeName;
              setModalState(() {
                filteredIcons = widget.viewModel.editingData.availableIcons.where((icon) {
                  final label = icon.labels[locale] ?? icon.iconName;
                  return label.toLowerCase().contains(query.toLowerCase());
                }).toList();
              });
            }

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: CustomizationPicker(
                  title: tr.categoryCustomization,
                  previewWidget: CategoryIcon(
                    icon: _tempIcon,
                    color: _tempColor,
                    size: 88,
                  ),
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
                          onChange: filterIcons,
                          onFieldSubmitted: (v) {
                            if (filteredIcons.isNotEmpty) {
                              setModalState(() => _tempIcon = filteredIcons.first);
                            }
                          },
                        ),
                        SizedBox(
                          height: 260,
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                            itemCount: filteredIcons.length,
                            itemBuilder: (context, index) {
                              final iconItem = filteredIcons[index];
                              final isSelected = _tempIcon.iconName == iconItem.iconName;

                              return Container(
                                decoration: BoxDecoration(
                                  color:theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setModalState(() => _tempIcon = iconItem),
                                  child: Icon(
                                    IconPickerIcon(
                                      name: iconItem.iconName,
                                      data: iconItem.toIconData(),
                                      pack: iconItem.iconPack,
                                    ).data,
                                    size: 28,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    ColorWheel(
                      key: const ValueKey('category_color_wheel'),
                      color: _tempColor,
                      onChanged: (color) => setModalState(() => _tempColor = color),
                    ),
                  ],
                  onValidate: () {
                    widget.viewModel.editingData.icon = _tempIcon;
                    widget.viewModel.editingData.color = _tempColor;
                    setState(() {});
                    Navigator.pop(context);
                  },
                  onCancel: () => Navigator.pop(context),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, child) {
        return EntityForm(
          formKey: widget.formKey,
          focusNode: _nameFocusNode,
          leadingWidget: CategoryIcon(
            icon: _tempIcon,
            color: _tempColor,
            size: 52,
            onTap: () => _openCustomizationPicker(context),
          ),
          nameController: widget.viewModel.editingData.nameController,
          labelText: tr.categoryName,
          validator: (v) => v == null || v.trim().isEmpty ? tr.nameRequired : null,
          onSubmit: () {
            widget.viewModel.editingData.icon = _tempIcon;
            widget.viewModel.editingData.color = _tempColor;

            if (widget.category?.id == null) {
              widget.viewModel.createCategory(widget.category!);
            } else {
              widget.viewModel.updateCategory(widget.category!);
            }
          },
          onCancel: () => widget.category?.id == null
              ? widget.viewModel.removeCategory(widget.category!)
              : widget.viewModel.cancelEdit(),
        );
      },
    );
  }
}