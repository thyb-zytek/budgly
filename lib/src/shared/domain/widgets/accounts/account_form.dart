import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/avatar_customization_sheet.dart';
import 'package:budgly/src/shared/ui/widgets/image/account_image_picker.dart';
import 'package:budgly/src/shared/ui/mixins/pulse_hint_animation.dart';
import 'package:budgly/src/shared/ui/widgets/forms/entity_form.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
import 'package:flutter/material.dart';

class AccountForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final Color initialColor;
  final String? initialPicture;
  final Future<String?> Function(BuildContext context)? pickImage;
  final ValueChanged<Color>? onColorChanged;
  final ValueChanged<String?>? onPictureChanged;
  final VoidCallback? onSubmit;
  final VoidCallback? onCancel;
  final bool withPulse;
  final bool withHint;
  final bool compact;
  final bool enabled;

  const AccountForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.initialColor,
    this.initialPicture,
    this.pickImage,
    this.onColorChanged,
    this.onPictureChanged,
    this.onSubmit,
    this.onCancel,
    this.withPulse = false,
    this.withHint = false,
    this.compact = false,
    this.enabled = true,
  });

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm>
    with TickerProviderStateMixin, PulseHintAnimationMixin {
  String? _tempPicture;
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
    _tempPicture = widget.initialPicture;
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
  void didUpdateWidget(covariant AccountForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPicture != oldWidget.initialPicture) {
      _tempPicture = widget.initialPicture;
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

  bool get _isTempLocalPicture =>
      _tempPicture != null && !_tempPicture!.startsWith('http');

  Future<void> _openAvatarPicker(BuildContext context, String initial) async {
    cancelHint();
    var picture = _tempPicture;
    var color = _tempColor;
    final confirmed = await showAvatarCustomizationSheet(
      context,
      initial: initial,
      initialPicture: picture,
      initialColor: color,
      pickImage: widget.pickImage == null
          ? () => AccountImagePicker.pickAndCropImage(context)
          : () => widget.pickImage!(context),
      onPictureChanged: (value) => picture = value,
      onColorChanged: (value) => color = value,
    );
    if (!mounted) return;
    if (confirmed) {
      setState(() {
        _tempPicture = picture;
        _tempColor = color;
      });
      widget.onPictureChanged?.call(_tempPicture);
      widget.onColorChanged?.call(_tempColor);
    }
    onHintEnabled();
  }

  Widget _avatar() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: widget.nameController,
    builder: (context, value, _) {
      final initial = value.text.isNotEmpty ? value.text[0] : 'A';
      return PulseHint(
        pulseAnimation: pulseAnimation,
        hintAnimation: hintAnimation,
        child: Avatar(
          initial: initial.toUpperCase(),
          backgroundColor: _tempColor,
          picture: _tempPicture,
          isLocalPicture: _isTempLocalPicture,
          size: 52,
          onTap: widget.enabled
              ? () => _openAvatarPicker(context, initial.toUpperCase())
              : null,
          showEditBadge: widget.enabled,
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    if (widget.compact) {
      return LayoutBuilder(
        builder: (context, constraints) => Row(
          spacing: 8,
          children: [
            _avatar(),
            Expanded(
              child: SizedBox(
                width: constraints.maxWidth,
                child: TextInput(
                  focusNode: _nameFocusNode,
                  controller: widget.nameController,
                  labelText: tr.accountName,
                  hotValidating: (v) =>
                      v == null || v.trim().isEmpty ? tr.nameRequired : null,
                  textInputAction: TextInputAction.done,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return EntityForm(
      formKey: widget.formKey,
      focusNode: _nameFocusNode,
      leadingWidget: _avatar(),
      nameController: widget.nameController,
      labelText: tr.accountName,
      validator: (v) => v == null || v.trim().isEmpty ? tr.nameRequired : null,
      onSubmit: widget.onSubmit ?? () {},
      onCancel: widget.onCancel ?? () {},
    );
  }
}
