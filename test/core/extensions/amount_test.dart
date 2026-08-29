import 'package:budgly/src/core/extensions/amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses comma decimals', () {
    expect(parseAmount('12,35'), 12.35);
  });

  test('preserves the exact value entered', () {
    expect(parseAmount('12.35'), 12.35);
    expect(parseAmount('12.345'), 12.345);
    expect(parseAmount('12.341'), 12.341);
    expect(parseAmount('12.00'), 12.0);
  });

  test('rejects invalid and non-positive amounts', () {
    expect(parseAmount('abc'), isNull);
    expect(parseAmount('0'), isNull);
    expect(parseAmount('-1'), isNull);
  });
}