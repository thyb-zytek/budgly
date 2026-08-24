import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/amount_format_incrementer.dart';
import 'package:budgly/src/shared/ui/widgets/layout/preference_section.dart';
import 'package:flutter/material.dart';

class AmountForm extends StatelessWidget {
  final int amountDecimalPlaces;
  final ValueChanged<int> onChanged;
  final String currency;

  const AmountForm({
    super.key,
    required this.amountDecimalPlaces,
    required this.onChanged,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return PreferenceSection(
      title: tr.amountFormat,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          shape: BoxShape.rectangle,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: AmountFormatIncrementer(
          decimalPlaces: amountDecimalPlaces,
          onChanged: onChanged,
          currency: currency
        ),
      ),
    );
  }
}
