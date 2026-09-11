import 'package:budgly/src/pages/settings/preferences/widgets/amount_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('AmountForm', () {
    testWidgets('incrementing and decrementing calls onChanged with the new value', (tester) async {
      var lastValue = -1;

      await pumpApp(
        tester,
        AmountForm(
          amountDecimalPlaces: 1,
          currency: 'EUR',
          onChanged: (value) => lastValue = value,
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(lastValue, 2);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(lastValue, 0);
    });

    testWidgets('does not go above the maximum of 2 decimal places', (tester) async {
      var changeCalls = 0;

      await pumpApp(
        tester,
        AmountForm(
          amountDecimalPlaces: 2,
          currency: 'EUR',
          onChanged: (_) => changeCalls++,
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(changeCalls, 0);
    });

    testWidgets('does not go below the minimum of 0 decimal places', (tester) async {
      var changeCalls = 0;

      await pumpApp(
        tester,
        AmountForm(
          amountDecimalPlaces: 0,
          currency: 'EUR',
          onChanged: (_) => changeCalls++,
        ),
      );

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(changeCalls, 0);
    });
  });
}
