import 'package:budgly/src/core/extensions/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('en_US');
  });

  group('CurrencyIcon', () {
    test('EUR returns euro icon', () {
      expect('EUR'.currencyIcon, Icons.euro_symbol_rounded);
    });

    test('USD returns dollar icon', () {
      expect('USD'.currencyIcon, Icons.attach_money_rounded);
    });

    test('GBP returns pound icon', () {
      expect('GBP'.currencyIcon, Icons.currency_pound_rounded);
    });

    test('unknown currency defaults to euro', () {
      expect('JPY'.currencyIcon, Icons.euro_symbol_rounded);
    });
  });

  group('formatCurrency', () {
    test('formats EUR in French locale', () {
      final result = formatCurrency(
        amount: 12.50,
        currencyCode: 'EUR',
        localeName: 'fr_FR',
      );
      expect(result, contains('12,50'));
      expect(result, contains('€'));
    });

    test('formats USD in English locale', () {
      final result = formatCurrency(
        amount: 12.50,
        currencyCode: 'USD',
        localeName: 'en_US',
      );
      expect(result, contains('12.50'));
      expect(result, contains('\$'));
    });

    test('formats GBP in English locale', () {
      final result = formatCurrency(
        amount: 12.50,
        currencyCode: 'GBP',
        localeName: 'en_US',
      );
      expect(result, contains('£'));
    });

    test('formats integer amount without decimals by default', () {
      final result = formatCurrency(
        amount: 12.00,
        currencyCode: 'EUR',
        localeName: 'fr_FR',
      );
      expect(result, isNot(contains(',')));
    });

    test('forceDecimal keeps decimal places even for integers', () {
      final result = formatCurrency(
        amount: 12.00,
        currencyCode: 'EUR',
        localeName: 'fr_FR',
        forceDecimal: true,
      );
      expect(result, contains(',00'));
    });

    test('respects decimalPlaces = 0', () {
      final result = formatCurrency(
        amount: 12.35,
        currencyCode: 'EUR',
        localeName: 'fr_FR',
        decimalPlaces: 0,
      );
      // Should be rounded up to 13
      expect(result, contains('13'));
    });

    test('respects decimalPlaces = 1', () {
      final result = formatCurrency(
        amount: 12.31,
        currencyCode: 'EUR',
        localeName: 'fr_FR',
        decimalPlaces: 1,
      );
      expect(result, contains('12,4'));
    });
  });
}
