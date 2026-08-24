import 'package:budgly/src/core/extensions/amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses comma decimals', () {
    expect(parseAmount('12,35'), 12.35);
  });

  test('rounds up to the configured precision', () {
    expect(parseAmount('12.35', decimalPlaces: 0), 13);
    expect(parseAmount('12.31', decimalPlaces: 1), 12.4);
    expect(parseAmount('12.35', decimalPlaces: 2), 12.35);
    expect(parseAmount('12.00', decimalPlaces: 0), 12);
  });

  test('clamps precision to 0..2', () {
    expect(parseAmount('12.351', decimalPlaces: 3), 12.36);
    expect(parseAmount('12.35', decimalPlaces: -1), 13);
  });

  test('rejects invalid and non-positive amounts', () {
    expect(parseAmount('abc'), isNull);
    expect(parseAmount('0'), isNull);
    expect(parseAmount('-1'), isNull);
  });
}
