import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/shared/ui/widgets/forms/form_actions.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

class EntityForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final Widget leadingWidget;
  final TextEditingController nameController;
  final String labelText;
  final String? Function(String?)? validator;
  final void Function(String)? onTextChange;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final bool denseButtons;
  final FocusNode? focusNode;
  final List<Widget>? extraFields;

  /// Whether to render the validate/cancel action row.
  ///
  /// Set to `false` when the host provides its own submit affordance while
  /// still reusing the entity form's layout (e.g. the onboarding steps).
  final bool showActions;

  /// Optional helper line rendered directly under the leading widget and name
  /// field row.
  ///
  /// Use it to explain an interaction attached to the leading widget, e.g. that
  /// tapping the avatar/icon opens a customization sheet. Keeping it in the
  /// form (rather than below the whole step) keeps the instruction visually
  /// tied to the element it describes.
  final String? leadingHint;

  const EntityForm({
    super.key,
    required this.formKey,
    required this.leadingWidget,
    required this.nameController,
    required this.labelText,
    this.validator,
    this.onTextChange,
    required this.onSubmit,
    required this.onCancel,
    this.denseButtons = true,
    this.focusNode,
    this.extraFields,
    this.showActions = true,
    this.leadingHint,
  });

  void _onSubmit() {
    if (formKey.currentState!.validate()) {
      onSubmit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: 8,
                children: [
                  leadingWidget,
                  Expanded(
                    child: TextInput(
                      focusNode: focusNode,
                      controller: nameController,
                      labelText: labelText,
                      onChange: onTextChange,
                      hotValidating:
                          validator ??
                          (v) => v == null || v.trim().isEmpty
                              ? tr.nameRequired
                              : null,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onSubmit(),
                    ),
                  ),
                ],
              ),
              if (leadingHint != null) ...[
                SizedBox(height: BudglySpacing.xs),
                Text(
                  leadingHint!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          ...?extraFields,
          if (showActions)
            FormActions(
              destructiveCancel: true,
              dense: denseButtons,
              onCancel: onCancel,
              onSubmit: _onSubmit,
            ),
        ],
      ),
    );
  }
}
