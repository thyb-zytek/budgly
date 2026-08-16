import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension CurrencyIcon on String {
  IconData get currencyIcon {
    switch (this) {
      case 'USD':
        return Icons.attach_money_rounded;
      case 'GBP':
        return Icons.currency_pound_rounded;
      case 'EUR':
      default:
        return Icons.euro_symbol_rounded;
    }
  }
}

String formatCurrency({
  required double amount,
  required String currencyCode,
  required String localeName,
  int decimalDigits = 0,
}) {
  return NumberFormat.currency(
    locale: localeName,
    symbol: _currencySymbol(currencyCode),
    decimalDigits: decimalDigits,
  ).format(amount);
}

String _currencySymbol(String currencyCode) {
  switch (currencyCode) {
    case 'USD':
      return '\$';
    case 'GBP':
      return '£';
    case 'EUR':
    default:
      return '€';
  }
}
