import 'package:budgly/src/services/calculators/category_threshold_calculator.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_threshold_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _calculator = CategoryThresholdCalculator();

CategoryThresholdProgress _progress({required double total, double? threshold}) {
  return _calculator.calculate(total: total, threshold: threshold);
}

LinearProgressIndicator _bar(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));

void main() {
  group('CategoryThresholdBar', () {
    testWidgets('renders nothing when the threshold is disabled', (tester) async {
      await pumpApp(
        tester,
        CategoryThresholdBar(
          progress: _progress(total: 50, threshold: null),
          currencyCode: 'EUR',
          localeName: 'fr',
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows the remaining amount while under threshold', (tester) async {
      await pumpApp(
        tester,
        CategoryThresholdBar(
          progress: _progress(total: 50, threshold: 100),
          currencyCode: 'EUR',
          localeName: 'fr',
        ),
      );

      expect(find.textContaining('Reste'), findsOneWidget);
    });

    testWidgets('shows the overshoot amount once exceeded', (tester) async {
      await pumpApp(
        tester,
        CategoryThresholdBar(
          progress: _progress(total: 120, threshold: 100),
          currencyCode: 'EUR',
          localeName: 'fr',
        ),
      );

      expect(find.textContaining('Dépassement'), findsOneWidget);
    });

    testWidgets('the warning color is a distinct blend, not a raw channel override', (tester) async {
      // Regression test: the bar used to compute the warning color via
      // `scheme.error.withValues(green: 0.5)`, which just overwrote the
      // green channel of an already red-dominant color instead of
      // producing a genuinely different warning tone. That made the
      // warning and exceeded states look almost identical.
      await pumpApp(
        tester,
        CategoryThresholdBar(
          progress: _progress(total: 85, threshold: 100), // >= 80% warning boundary
          currencyCode: 'EUR',
          localeName: 'fr',
        ),
      );
      final warningColor = _bar(tester).color;

      await pumpApp(
        tester,
        CategoryThresholdBar(
          progress: _progress(total: 120, threshold: 100),
          currencyCode: 'EUR',
          localeName: 'fr',
        ),
      );
      final exceededColor = _bar(tester).color;

      expect(warningColor, isNot(exceededColor));
    });
  });
}
