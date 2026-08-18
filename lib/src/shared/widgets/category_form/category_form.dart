import 'dart:async';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/pages/settings/widgets/customization_picker.dart';
import 'package:budgly/src/pages/settings/widgets/entity_form.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/shared/view_models/category_form_view_model.dart';
import 'package:budgly/src/shared/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/shared/widgets/color_wheel/color_wheel.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:budgly/src/shared/widgets/tabs/tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';

class CategoryForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final CategoryFormViewModel viewModel;
  final Category? category;
  final bool withPulse;
  final bool withHint;
  final bool compact;
  final bool enabled;

  const CategoryForm({
    super.key,
    required this.formKey,
    required this.viewModel,
    this.category,
    this.withPulse = false,
    this.withHint = false,
    this.compact = false,
    this.enabled = true,
  });

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm>
    with SingleTickerProviderStateMixin {
  late CategoryIcon _tempIcon;
  late Color _tempColor;
  late final FocusNode _nameFocusNode;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  AnimationController? _hintController;
  Animation<double>? _hintAnimation;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _tempIcon = widget.viewModel.categoryEditingData.icon;
    _tempColor = widget.viewModel.categoryEditingData.color;
    _nameFocusNode = FocusNode();

    if (widget.withPulse) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
      _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    }

    if (widget.withHint && widget.enabled) {
      _hintController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      _hintAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _hintController!, curve: Curves.easeInOut),
      );
      _scheduleHint();
    }

    if (widget.category?.id == null) {
      Future.delayed(
        const Duration(milliseconds: 300),
        () => _nameFocusNode.requestFocus(),
      );
    }
  }

  void _scheduleHint() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || !widget.enabled) return;
      _hintController!.forward(from: 0).then((_) => _scheduleHint());
    });
  }

  @override
  void didUpdateWidget(covariant CategoryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIcon = widget.viewModel.categoryEditingData.icon;
    final newColor = widget.viewModel.categoryEditingData.color;
    if (newIcon != _tempIcon) _tempIcon = newIcon;
    if (newColor != _tempColor) _tempColor = newColor;

    if (widget.enabled && !oldWidget.enabled && widget.withHint) {
      _scheduleHint();
    }
    if (!widget.enabled) {
      _hintTimer?.cancel();
      _hintController?.value = 0;
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hintController?.dispose();
    _pulseController?.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _openCustomizationPicker(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final searchController = TextEditingController();
    List<CategoryIcon> filteredIcons =
        widget.viewModel.categoryEditingData.availableIcons;

    _hintTimer?.cancel();
    _hintController?.value = 0;

    showAppBottomSheet(
      context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterIcons(String query) {
              final locale = tr.localeName;
              setModalState(() {
                filteredIcons =
                    widget.viewModel.categoryEditingData.availableIcons.where((icon) {
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
                    icon: _tempIcon,
                    color: _tempColor,
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
                                  () => _tempIcon = filteredIcons.first);
                            }
                          },
                        ),
                        SizedBox(
                          height: 220,
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 1,
                            ),
                            itemCount: filteredIcons.length,
                            itemBuilder: (context, index) {
                              final iconItem = filteredIcons[index];
                              final isSelected =
                                  _tempIcon.iconName == iconItem.iconName;

                              return Container(
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest,
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
                                      () => _tempIcon = iconItem),
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
                      key: const ValueKey('category_color_wheel'),
                      color: _tempColor,
                      onChanged: (color) =>
                          setModalState(() => _tempColor = color),
                    ),
                  ],
                  onValidate: () {
                    widget.viewModel.categoryEditingData.icon = _tempIcon;
                    widget.viewModel.categoryEditingData.color = _tempColor;
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

  Widget _buildCategoryIcon() {
    Widget icon = CategoryIconView(
      icon: _tempIcon,
      color: _tempColor,
      size: 52,
      onTap: widget.enabled ? () => _openCustomizationPicker(context) : null,
    );

    if (_pulseAnimation != null) {
      icon = ScaleTransition(scale: _pulseAnimation!, child: icon);
    }
    if (_hintAnimation != null) {
      icon = ScaleTransition(scale: _hintAnimation!, child: icon);
    }

    return icon;
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, child) {
        if (widget.compact) {
          return Row(
            spacing: 8,
            children: [
              _buildCategoryIcon(),
              Expanded(
                child: TextInput(
                  focusNode: _nameFocusNode,
                  controller: widget.viewModel.categoryEditingData.nameController,
                  labelText: tr.categoryName,
                  textInputAction: TextInputAction.done,
                  onChange: (_) => setState(() {}),
                ),
              ),
            ],
          );
        }

        return EntityForm(
          formKey: widget.formKey,
          focusNode: _nameFocusNode,
          leadingWidget: _buildCategoryIcon(),
          nameController: widget.viewModel.categoryEditingData.nameController,
          labelText: tr.categoryName,
          validator: (v) =>
              v == null || v.trim().isEmpty ? tr.nameRequired : null,
          onSubmit: () {
            widget.viewModel.categoryEditingData.icon = _tempIcon;
            widget.viewModel.categoryEditingData.color = _tempColor;

            if (widget.category?.id == null) {
              widget.viewModel.createCategory(
                widget.category ??
                    Category(
                      name: '',
                      color: _tempColor,
                      icon: _tempIcon,
                      accountId: '',
                    ),
              );
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
