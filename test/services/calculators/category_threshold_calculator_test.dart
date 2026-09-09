import 'package:budgly/src/services/calculators/category_threshold_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = CategoryThresholdCalculator();
  test('calculates normal state below warning boundary', () {
    final result = calculator.calculate(total: 79, threshold: 100);
    expect(result.state, CategoryThresholdState.normal);
    expect(result.progress, .79);
    expect(result.remaining, 21);
  });
  test('uses warning state at 80 percent boundary', () {
    expect(calculator.calculate(total: 80, threshold: 100).state, CategoryThresholdState.warning);
  });
  test('uses exceeded state at threshold and clamps progress', () {
    final result = calculator.calculate(total: 130, threshold: 100);
    expect(result.state, CategoryThresholdState.exceeded);
    expect(result.progress, 1);
    expect(result.rawProgress, 1.3);
    expect(result.overshoot, 30);
  });
  test('disables missing or zero threshold', () {
    expect(calculator.calculate(total: 10, threshold: null).isEnabled, isFalse);
    expect(calculator.calculate(total: 10, threshold: 0).isEnabled, isFalse);
  });
}
