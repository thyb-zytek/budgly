import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyIcon', () {
    test('USD maps to the dollar icon', () {
      expect('USD'.currencyIcon, Icons.attach_money_rounded);
    });

    test('GBP maps to the pound icon', () {
      expect('GBP'.currencyIcon, Icons.currency_pound_rounded);
    });

    test('EUR maps to the euro icon', () {
      expect('EUR'.currencyIcon, Icons.euro_symbol_rounded);
    });

    test('an unknown currency code falls back to the euro icon', () {
      expect('XXX'.currencyIcon, Icons.euro_symbol_rounded);
    });
  });

  // parseAmount itself is already covered by amount_test.dart — only
  // normalizeAmount (applied to amounts at display time) is exercised
  // directly here.
  group('normalizeAmount', () {
    test('rounds up to 2 decimal places by default', () {
      expect(normalizeAmount(1.201), 1.21);
    });

    test('clamps decimalPlaces above 2 down to 2', () {
      expect(normalizeAmount(1.239, decimalPlaces: 5), 1.24);
    });

    test('clamps negative decimalPlaces up to 0', () {
      expect(normalizeAmount(1.2, decimalPlaces: -1), 2.0);
    });

    test('rounds up to whole numbers when decimalPlaces is 0', () {
      expect(normalizeAmount(1.1, decimalPlaces: 0), 2.0);
    });

    test('leaves an already-exact amount unchanged', () {
      expect(normalizeAmount(10.0), 10.0);
    });
  });

  group('formatCurrency', () {
    test('omits decimals for a whole amount by default', () {
      final result = formatCurrency(
        amount: 10,
        currencyCode: 'USD',
        localeName: 'en_US',
      );
      expect(result, isNot(contains('.')));
      expect(result, contains('10'));
      expect(result, contains(r'$'));
    });

    test('shows decimals for a non-whole amount', () {
      final result = formatCurrency(
        amount: 10.5,
        currencyCode: 'USD',
        localeName: 'en_US',
      );
      expect(result, contains('.'));
      expect(result, contains('10.5'));
    });

    test('forceDecimal shows decimals even for a whole amount', () {
      final result = formatCurrency(
        amount: 10,
        currencyCode: 'USD',
        localeName: 'en_US',
        forceDecimal: true,
      );
      expect(result, contains('.'));
    });

    test('uses the pound symbol for GBP', () {
      final result = formatCurrency(
        amount: 5,
        currencyCode: 'GBP',
        localeName: 'en_US',
      );
      expect(result, contains('£'));
    });

    test('falls back to the euro symbol for an unknown currency code', () {
      final result = formatCurrency(
        amount: 5,
        currencyCode: 'XXX',
        localeName: 'en_US',
      );
      expect(result, contains('€'));
    });
  });
}
