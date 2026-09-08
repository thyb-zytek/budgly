import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/shared/domain/view_models/account_form_view_model.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/avatar_customization_sheet.dart';
import 'package:budgly/src/shared/ui/mixins/pulse_hint_animation.dart';
import 'package:budgly/src/shared/ui/widgets/forms/entity_form.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
import 'package:flutter/material.dart';

class AccountForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final AccountFormViewModel viewModel;
  final Account? account;
  final bool withPulse;
  final bool withHint;
  final bool compact;
  final bool enabled;

  const AccountForm({
    super.key,
    required this.formKey,
    required this.viewModel,
    this.account,
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
    _tempPicture = widget.viewModel.editingData.picture;
    _tempColor = widget.viewModel.editingData.color;
    _nameFocusNode = FocusNode();

    initPulseHintAnimations();

    if (widget.account?.id == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocusNode.requestFocus();
    });
    }
  }

  @override
  void didUpdateWidget(covariant AccountForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPicture = widget.viewModel.editingData.picture;
    final newColor = widget.viewModel.editingData.color;
    if (newPicture != _tempPicture) _tempPicture = newPicture;
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

  bool get _isTempLocalPicture =>
      _tempPicture != null && !_tempPicture!.startsWith('http');

  void _openAvatarPicker(BuildContext context, String initial) {
    cancelHint();

    showAvatarCustomizationSheet(
      context,
      initial: initial,
      initialPicture: _tempPicture,
      initialColor: _tempColor,
      pickImage: () => widget.viewModel.pickImage(context),
      onPictureChanged: (picture) => _tempPicture = picture,
      onColorChanged: (color) => _tempColor = color,
    ).then((confirmed) {
      if (confirmed) {
        widget.viewModel.editingData.picture = _tempPicture;
        widget.viewModel.editingData.color = _tempColor;
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
          return LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                spacing: 8,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable:
                        widget.viewModel.editingData.nameController,
                    builder: (context, value, _) {
                      final initial =
                          value.text.isNotEmpty ? value.text[0] : 'A';
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
                              ? () => _openAvatarPicker(
                                  context,
                                  initial.toUpperCase(),
                                )
                              : null,
                          showEditBadge: widget.enabled,
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: TextInput(
                        focusNode: _nameFocusNode,
                        controller: widget.viewModel.editingData.nameController,
                        labelText: tr.accountName,
                        hotValidating: (v) =>
                            v == null || v.trim().isEmpty ? tr.nameRequired : null,
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }

        return EntityForm(
          formKey: widget.formKey,
          focusNode: _nameFocusNode,
          leadingWidget: ValueListenableBuilder<TextEditingValue>(
            valueListenable:
                widget.viewModel.editingData.nameController,
            builder: (context, value, _) {
              final initial =
                  value.text.isNotEmpty ? value.text[0] : 'A';
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
                          ? () => _openAvatarPicker(
                              context,
                              initial.toUpperCase(),
                            )
                          : null,
                      showEditBadge: widget.enabled,
                    ),
                  );
            },
          ),
          nameController: widget.viewModel.editingData.nameController,
          labelText: tr.accountName,
          validator: (v) =>
              v == null || v.trim().isEmpty ? tr.nameRequired : null,
          onSubmit: () {
            widget.viewModel.editingData.picture = _tempPicture;
            widget.viewModel.editingData.color = _tempColor;

            if (widget.account?.id == null) {
              widget.viewModel.createAccount(
                widget.account ??
                    Account(name: '', color: _tempColor),
              );
            } else {
              widget.viewModel.updateAccount(widget.account!);
            }
          },
          onCancel: () => widget.account?.id == null
              ? widget.viewModel.removeAccount(widget.account!)
              : widget.viewModel.cancelEdit(),
        );
      },
    );
  }
}
