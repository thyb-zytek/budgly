import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/settings/widgets/accounts/view_model.dart';
import 'package:budgly/src/pages/settings/widgets/customization_picker.dart';
import 'package:budgly/src/pages/settings/widgets/entity_form.dart';
import 'package:budgly/src/shared/widgets/avatar/avatar.dart';
import 'package:budgly/src/shared/widgets/buttons/button.dart';
import 'package:budgly/src/shared/widgets/buttons/constants.dart';
import 'package:budgly/src/shared/widgets/inputs/color_wheel.dart';
import 'package:budgly/src/shared/widgets/tabs/tab.dart';
import 'package:flutter/material.dart';

class AccountForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final AccountsViewModel viewModel;
  final Account? account;

  const AccountForm({
    super.key,
    required this.formKey,
    required this.viewModel,
    this.account
  });

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  String? _tempPicture;
  late Color _tempColor;
  late final FocusNode _nameFocusNode;

  @override
  void initState() {
    super.initState();
    _tempPicture = widget.viewModel.editingData.picture;
    _tempColor = widget.viewModel.editingData.color;
    _nameFocusNode = FocusNode();

    if (widget.account?.id == null) {
      Future.delayed(const Duration(milliseconds: 300), () => _nameFocusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    super.dispose();
  }

  bool get _isTempLocalPicture => _tempPicture != null && !_tempPicture!.startsWith('http');

  void _openAvatarPicker(BuildContext context, String initial) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: CustomizationPicker(
                  title: tr.avatarCustomization,
                  previewWidget: Avatar(
                    initial: initial,
                    picture: _tempPicture,
                    isLocalPicture: _isTempLocalPicture,
                    backgroundColor: _tempColor,
                    size: 88,
                    canRemove: _tempPicture != null,
                    onRemove: () => setModalState(() => _tempPicture = null),
                  ),
                  tabTitles: [
                    TabTitle(icon: Icons.photo_library_rounded, title: tr.picture),
                    TabTitle(icon: Icons.palette_rounded, title: tr.color),
                  ],
                  tabs: [
                    SizedBox(
                      width: double.infinity,
                      child: BudglyButton(
                        onPressed: () => widget.viewModel.pickImage(context).then((path) {
                          if (path != null) setModalState(() => _tempPicture = path);
                        }),
                        leadingIcon: Icons.upload_rounded,
                        type: ButtonType.outlined,
                        text: tr.pickImage,
                      ),
                    ),
                    ColorWheel(
                      key: const ValueKey('color'),
                      color: _tempColor,
                      onChanged: (color) => setModalState(() => _tempColor = color),
                    ),
                  ],
                  onValidate: () {
                    widget.viewModel.editingData.picture = _tempPicture;
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
          leadingWidget: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.viewModel.editingData.nameController,
            builder: (context, value, child) {
              final initial = value.text.isNotEmpty ? value.text[0] : 'A';

              return Avatar(
                initial: initial.toUpperCase(),
                backgroundColor: _tempColor,
                picture: _tempPicture,
                isLocalPicture: _isTempLocalPicture,
                size: 52,
                onTap: () => _openAvatarPicker(context, initial),
              );
            },
          ),
          nameController: widget.viewModel.editingData.nameController,
          labelText: tr.accountName,
          validator: (v) => v == null || v.trim().isEmpty ? tr.nameRequired : null,
          onSubmit: () {
            widget.viewModel.editingData.picture = _tempPicture;
            widget.viewModel.editingData.color = _tempColor;

            if (widget.account?.id == null) {
              widget.viewModel.createAccount(widget.account!);
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