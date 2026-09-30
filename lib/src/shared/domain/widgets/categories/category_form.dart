import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_customization_sheet.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/shared/ui/mixins/pulse_hint_animation.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/shared/ui/widgets/forms/entity_form.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

class CategoryForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController? monthlyThresholdController;
  final CategoryIcon initialIcon;
  final Color initialColor;
  final List<CategoryIcon> availableIcons;
  final ValueChanged<CategoryIcon>? onIconChanged;
  final ValueChanged<Color>? onColorChanged;
  final VoidCallback? onSubmit;
  final VoidCallback? onCancel;
  final bool withPulse;
  final bool withHint;
  final bool compact;
  final bool enabled;

  const CategoryForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.initialIcon,
    required this.initialColor,
    required this.availableIcons,
    this.monthlyThresholdController,
    this.onIconChanged,
    this.onColorChanged,
    this.onSubmit,
    this.onCancel,
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
    _tempIcon = widget.initialIcon;
    _tempColor = widget.initialColor;
    _nameFocusNode = FocusNode();
    initPulseHintAnimations();
    if (widget.nameController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CategoryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIcon != oldWidget.initialIcon) {
      _tempIcon = widget.initialIcon;
    }
    if (widget.initialColor != oldWidget.initialColor) {
      _tempColor = widget.initialColor;
    }
    if (widget.enabled && !oldWidget.enabled && widget.withHint) {
      onHintEnabled();
    }
    if (!widget.enabled) onHintDisabled();
  }

  @override
  void dispose() {
    disposePulseHintAnimations();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openCustomizationPicker(BuildContext context) async {
    cancelHint();
    var icon = _tempIcon;
    var color = _tempColor;
    final confirmed = await showCategoryCustomizationSheet(
      context,
      availableIcons: widget.availableIcons,
      initialIcon: icon,
      initialColor: color,
      previewBuilder: (context, selectedIcon, selectedColor) =>
          CategoryIconView(icon: selectedIcon, color: selectedColor, size: 80),
      onIconChanged: (value) => icon = value,
      onColorChanged: (value) => color = value,
    );
    if (!mounted) return;
    if (confirmed) {
      setState(() {
        _tempIcon = icon;
        _tempColor = color;
      });
      widget.onIconChanged?.call(_tempIcon);
      widget.onColorChanged?.call(_tempColor);
    }
    onHintEnabled();
  }

  Widget _icon() => PulseHint(
    pulseAnimation: pulseAnimation,
    hintAnimation: hintAnimation,
    child: CategoryIconView(
      icon: _tempIcon,
      color: _tempColor,
      size: 52,
      onTap: widget.enabled ? () => _openCustomizationPicker(context) : null,
      showEditBadge: widget.enabled,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    if (widget.compact) {
      return Row(
        spacing: 8,
        children: [
          _icon(),
          Expanded(
            child: TextInput(
              focusNode: _nameFocusNode,
              controller: widget.nameController,
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
      leadingWidget: _icon(),
      nameController: widget.nameController,
      extraFields: [
        if (widget.monthlyThresholdController != null)
          TextInput(
            controller: widget.monthlyThresholdController!,
            labelText: tr.monthlyThreshold,
            hintText: tr.thresholdOptionalHint,
            type: InputType.currency,
          ),
      ],
      labelText: tr.categoryName,
      validator: (v) => v == null || v.trim().isEmpty ? tr.nameRequired : null,
      onSubmit: widget.onSubmit ?? () {},
      onCancel: widget.onCancel ?? () {},
    );
  }
}
