import 'package:budgly/src/core/extensions/currency.dart';
import 'package:flutter/material.dart';

class AmountFormatIncrementer extends StatelessWidget {
  const AmountFormatIncrementer({
    super.key,
    required this.decimalPlaces,
    required this.onChanged,
    required this.currency,
  });

  final int decimalPlaces;
  final ValueChanged<int> onChanged;
  final String currency;

  static const _min = 0;
  static const _max = 2;

  void _decrement() {
    if (decimalPlaces > _min) {
      onChanged(decimalPlaces - 1);
    }
  }

  void _increment() {
    if (decimalPlaces < _max) {
      onChanged(decimalPlaces + 1);
    }
  }

  String _exampleAmount(BuildContext context) {
    const value = 0.0;

    return formatCurrency(
      amount: value,
      currencyCode: currency,
      localeName: Localizations.localeOf(context).toLanguageTag(),
      decimalPlaces: decimalPlaces,
      forceDecimal: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: decimalPlaces > _min ? _decrement : null,
          icon: const Icon(Icons.remove),
        ),

        SizedBox(
          width: 100,
          child: Center(
            child: Text(
              _exampleAmount(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),

        IconButton(
          onPressed: decimalPlaces < _max ? _increment : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
