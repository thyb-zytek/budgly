import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:flutter/material.dart';

class FormActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final String? cancelLabel;
  final String? submitLabel;
  final ButtonType cancelType;
  final bool dense;
  final bool isLoading;

  const FormActions({
    super.key,
    required this.onCancel,
    required this.onSubmit,
    this.cancelLabel,
    this.submitLabel,
    this.cancelType = ButtonType.error,
    this.dense = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: FilledButton(
            style: cancelType.filledStyle(theme, dense: dense),
            onPressed: isLoading ? null : onCancel,
            child: Text(cancelLabel ?? tr.cancel),
          ),
        ),
        Expanded(
          child: FilledButton(
            style: ButtonType.primary.filledStyle(theme, dense: dense),
            onPressed: isLoading ? null : onSubmit,
            child: Text(submitLabel ?? tr.validate),
          ),
        ),
      ],
    );
  }
}
