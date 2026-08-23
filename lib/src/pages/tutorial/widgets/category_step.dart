import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/pages/tutorial/view_model.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:budgly/src/shared/ui/widgets/customization_picker.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/shared/ui/widgets/layout/color_wheel.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:budgly/src/shared/ui/widgets/tabs/tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide TextInput;
import 'package:flutter_iconpicker/flutter_iconpicker.dart';

class CategoryStep extends StatefulWidget {
  final TutorialViewModel viewModel;
  final VoidCallback onNext;

  const CategoryStep({
    super.key,
    required this.viewModel,
    required this.onNext,
  });

  @override
  State<CategoryStep> createState() => _CategoryStepState();
}

class _CategoryStepState extends State<CategoryStep> {
  late final FocusNode _nameFocusNode;

  @override
  void initState() {
    super.initState();
    _nameFocusNode = FocusNode();

    Future.delayed(
      const Duration(milliseconds: 300),
      () => _nameFocusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _openCustomizationPicker(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final vm = widget.viewModel;
    final searchController = TextEditingController();
    List<CategoryIcon> filteredIcons = vm.availableIcons;

    showAppBottomSheet(
      context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterIcons(String query) {
              final locale = tr.localeName;
              setModalState(() {
                filteredIcons = vm.availableIcons.where((icon) {
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
                  previewWidget: CategoryIconView(
                    icon: vm.categoryIcon ?? AppConstants.defaultCategoryIcon,
                    color: vm.categoryColor,
                    size: 80,
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
                              setModalState(
                                () => vm.setCategoryIcon(filteredIcons.first),
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
                            itemBuilder: (context, index) {
                              final iconItem = filteredIcons[index];
                              final currentIcon = vm.categoryIcon;
                              final isSelected =
                                  currentIcon?.iconName == iconItem.iconName;

                              return Container(
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setModalState(
                                    () => vm.setCategoryIcon(iconItem),
                                  ),
                                  child: Icon(
                                    IconPickerIcon(
                                      name: iconItem.iconName,
                                      data: iconItem.toIconData(),
                                      pack: iconItem.iconPack,
                                    ).data,
                                    size: 32,
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
                      key: const ValueKey('tutorial_cat_color'),
                      color: vm.categoryColor,
                      onChanged: (color) {
                        setModalState(() => vm.setCategoryColor(color));
                      },
                    ),
                  ],
                  onValidate: () {
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
    ).then((_) => searchController.dispose());
  }

  Future<void> _handleValidate() async {
    if (!widget.viewModel.isCategoryValid) return;
    final ok = await widget.viewModel.addCategory();
    if (!mounted) return;
    if (ok) {
      HapticFeedback.selectionClick();
      _nameFocusNode.requestFocus();
    }
  }

  Future<void> _handleNext() async {
    if (mounted) widget.onNext();
  }

  Widget _categoryTile(BuildContext context, Category category) {
    final theme = Theme.of(context);

    return TutorialPopIn(
      key: ValueKey(category.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (category.icon != null)
                CategoryIconView(
                  icon: category.icon!,
                  color: category.color ?? theme.colorScheme.primary,
                  size: 36,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name ?? '',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, size: 20),
                onPressed: () => widget.viewModel.removeCategory(category),
                color: theme.colorScheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final vm = widget.viewModel;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final currentIcon = vm.categoryIcon ?? AppConstants.defaultCategoryIcon;

        return TutorialStepScaffold(
          title: tr.tutorialStepCategories,
          subtitle: tr.tutorialStepCategoriesDescription,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Row(
                spacing: 16,
                children: [
                  GestureDetector(
                    onTap: () => _openCustomizationPicker(context),
                    child: CategoryIconView(
                      icon: currentIcon,
                      color: vm.categoryColor,
                      size: 56,
                    ),
                  ),
                  Expanded(
                    child: TextInput(
                      focusNode: _nameFocusNode,
                      controller: vm.categoryNameController,
                      labelText: tr.categoryName,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleValidate(),
                    ),
                  ),
                ],
              ),
              ListenableBuilder(
                listenable: vm.categoryNameController,
                builder: (context, _) {
                  final isValid = vm.isCategoryValid && !vm.isAddingCategory;
                  return vm.isAddingCategory
                      ? FilledButton.tonalIcon(
                          onPressed: isValid ? _handleValidate : null,
                          icon: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          label: Text(tr.add),
                        )
                      : FilledButton(
                          style: ButtonType.primary.filledStyle(theme),
                          onPressed: isValid ? _handleValidate : null,
                          child: Text(tr.add),
                        );
                },
              ),
              if (vm.createdCategories.isNotEmpty)
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: vm.createdCategories
                        .map((category) => _categoryTile(context, category))
                        .toList(),
                  ),
                ),
            ],
          ),
          primaryAction: ListenableBuilder(
            listenable: vm.categoryNameController,
            builder: (context, _) {
              final canProceed = vm.hasCategories;

              return SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: ButtonType.primary.filledStyle(theme),
                  onPressed: canProceed ? _handleNext : null,
                  child: Text(
                    tr.tutorialNext,
                    style: ButtonType.primary.labelStyle(theme),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
