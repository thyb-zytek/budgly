import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/shared/domain/view_models/category_form_view_model.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_customization_sheet.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/shared/ui/mixins/pulse_hint_animation.dart';
import 'package:budgly/src/shared/ui/widgets/forms/entity_form.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

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
    with TickerProviderStateMixin, PulseHintAnimationMixin {
  late CategoryIcon _tempIcon;
  late Color _tempColor;
  late final FocusNode _nameFocusNode;

  @override
  bool get withPulse => widget.withPulse;
  @override
  bool get withHint => widget.withHint;
  @override
  bool get hintEnabled => widget.enabled;

  @override
  void initState() {
    super.initState();
    _tempIcon = widget.viewModel.categoryEditingData.icon;
    _tempColor = widget.viewModel.categoryEditingData.color;
    _nameFocusNode = FocusNode();

    initPulseHintAnimations();

    if (widget.category?.id == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocusNode.requestFocus();
    });
    }
  }

  @override
  void didUpdateWidget(covariant CategoryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIcon = widget.viewModel.categoryEditingData.icon;
    final newColor = widget.viewModel.categoryEditingData.color;
    if (newIcon != _tempIcon) _tempIcon = newIcon;
    if (newColor != _tempColor) _tempColor = newColor;

    if (widget.enabled && !oldWidget.enabled && widget.withHint) {
      onHintEnabled();
    }
    if (!widget.enabled) {
      onHintDisabled();
    }
  }

  @override
  void dispose() {
    disposePulseHintAnimations();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _openCustomizationPicker(BuildContext context) {
    cancelHint();

    showCategoryCustomizationSheet(
      context,
      availableIcons: widget.viewModel.categoryEditingData.availableIcons,
      initialIcon: _tempIcon,
      initialColor: _tempColor,
      previewBuilder: (context, icon, color) => CategoryIconView(
        icon: icon,
        color: color,
        size: 80,
      ),
      onIconChanged: (icon) => _tempIcon = icon,
      onColorChanged: (color) => _tempColor = color,
    ).then((confirmed) {
      if (confirmed) {
        widget.viewModel.categoryEditingData.icon = _tempIcon;
        widget.viewModel.categoryEditingData.color = _tempColor;
      }
      if (!mounted) return;
      setState(() {});
    });
  }


  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, child) {
        if (widget.compact) {
          return Row(
            spacing: 8,
            children: [
              PulseHint(
                pulseAnimation: pulseAnimation,
                hintAnimation: hintAnimation,
                child: CategoryIconView(
                  icon: _tempIcon,
                  color: _tempColor,
                  size: 52,
                  onTap: widget.enabled
                      ? () => _openCustomizationPicker(context)
                      : null,
                  showEditBadge: widget.enabled,
                ),
              ),
              Expanded(
                child: TextInput(
                  focusNode: _nameFocusNode,
                  controller: widget.viewModel.categoryEditingData.nameController,
                  labelText: tr.categoryName,
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          );
        }

        return EntityForm(
          formKey: widget.formKey,
          focusNode: _nameFocusNode,
          leadingWidget: PulseHint(
            pulseAnimation: pulseAnimation,
            hintAnimation: hintAnimation,
            child: CategoryIconView(
              icon: _tempIcon,
              color: _tempColor,
              size: 52,
              onTap: widget.enabled
                  ? () => _openCustomizationPicker(context)
                  : null,
              showEditBadge: widget.enabled,
            ),
          ),
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
