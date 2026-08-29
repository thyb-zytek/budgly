import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

class CurrencyInput extends StatelessWidget {
  final TextEditingController controller;
  final String currencyCode;
  final String labelText;
  final String? Function(String?)? hotValidating;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  const CurrencyInput({
    super.key,
    required this.controller,
    required this.currencyCode,
    required this.labelText,
    this.hotValidating,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return TextInput(
      controller: controller,
      labelText: labelText,
      type: InputType.currency,
      suffix: Padding(
        padding: const EdgeInsets.only(right: BudglySpacing.sm),
        child: Icon(
          currencyCode.currencyIcon,
          size: 20,
          opticalSize: 14,
          color: theme.colorScheme.onSurface.withAlpha(155),
        ),
      ),
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
      hotValidating: hotValidating ?? (v) {
        final amount = double.tryParse((v ?? '').replaceAll(',', '.'));
        if (amount == null || amount <= 0) return tr.amountInvalid;
        return null;
      },
    );
  }
}
