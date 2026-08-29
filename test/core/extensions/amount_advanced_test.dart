import 'package:budgly/src/core/extensions/amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeAmount', () {
    test('rounds up (ceil) to 2 decimal places', () {
      expect(normalizeAmount(12.341), 12.35);
      expect(normalizeAmount(12.3401), 12.35);
    });

    test('rounds up to 1 decimal place', () {
      expect(normalizeAmount(12.31, decimalPlaces: 1), 12.4);
      expect(normalizeAmount(12.301, decimalPlaces: 1), 12.4);
    });

    test('rounds up to 0 decimal places (integer)', () {
      expect(normalizeAmount(12.01, decimalPlaces: 0), 13);
      expect(normalizeAmount(12.99, decimalPlaces: 0), 13);
      expect(normalizeAmount(12.0, decimalPlaces: 0), 12);
    });

    test('already exact value stays unchanged', () {
      expect(normalizeAmount(12.35), 12.35);
      expect(normalizeAmount(12.3), 12.3);
      expect(normalizeAmount(12.0), 12.0);
    });

    test('clamps negative decimalPlaces to 0', () {
      expect(normalizeAmount(12.35, decimalPlaces: -5), 13);
    });

    test('clamps decimalPlaces > 2 to 2', () {
      expect(normalizeAmount(12.351, decimalPlaces: 10), 12.36);
    });

    test('handles zero amount', () {
      expect(normalizeAmount(0), 0);
    });

    test('handles very small amount', () {
      expect(normalizeAmount(0.001), 0.01);
    });

    test('handles very large amount', () {
      expect(normalizeAmount(999999.991), 1000000.0);
    });

    test('ceil not floor for amounts like 10.001', () {
      expect(normalizeAmount(10.001), 10.01);
    });
  });

  group('parseAmount', () {
    test('parses simple decimal with dot', () {
      expect(parseAmount('12.35'), 12.35);
    });

    test('parses comma as decimal separator', () {
      expect(parseAmount('12,35'), 12.35);
    });

    test('trims whitespace', () {
      expect(parseAmount('  12.35  '), 12.35);
    });

    test('rejects zero', () {
      expect(parseAmount('0'), isNull);
    });

    test('rejects negative', () {
      expect(parseAmount('-5'), isNull);
    });

    test('rejects non-numeric', () {
      expect(parseAmount('abc'), isNull);
    });

    test('rejects empty string', () {
      expect(parseAmount(''), isNull);
    });

    test('rejects whitespace-only string', () {
      expect(parseAmount('   '), isNull);
    });

    test('returns the exact value without rounding', () {
      expect(parseAmount('12.341'), 12.341);
      expect(parseAmount('12.3401'), 12.3401);
    });

    test('handles integer input', () {
      expect(parseAmount('12'), 12);
    });

    test('handles very small positive amount', () {
      expect(parseAmount('0.01'), 0.01);
    });

    test('handles very large amount', () {
      expect(parseAmount('999999.99'), 999999.99);
    });
  });
}
