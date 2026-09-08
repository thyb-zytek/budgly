import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:flutter/material.dart';

class FormActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final String? cancelLabel;
  final String? submitLabel;
  final bool destructiveCancel;
  final bool destructiveSubmit;
  final bool dense;
  final bool isLoading;
  final bool isSubmitEnabled;

  const FormActions({
    super.key,
    required this.onCancel,
    required this.onSubmit,
    this.cancelLabel,
    this.submitLabel,
    this.destructiveCancel = false,
    this.destructiveSubmit = false,
    this.dense = true,
    this.isLoading = false,
    this.isSubmitEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: destructiveCancel
              ? FilledButton(
                  style: ButtonType.error.filledStyle(theme, dense: dense),
                  onPressed: isLoading ? null : onCancel,
                  child: Text(cancelLabel ?? tr.cancel),
                )
              : OutlinedButton(
                  style: ButtonType.secondary.outlinedStyle(theme, dense: dense),
                  onPressed: isLoading ? null : onCancel,
                  child: Text(cancelLabel ?? tr.cancel),
                ),
        ),
        Expanded(
          child: FilledButton(
            style: (destructiveSubmit ? ButtonType.error : ButtonType.primary)
                .filledStyle(theme, dense: dense),
            onPressed: (isLoading || !isSubmitEnabled) ? null : onSubmit,
            child: Text(submitLabel ?? tr.validate),
          ),
        ),
      ],
    );
  }
}
