import 'package:budgly/src/pages/settings/preferences/widgets/currency_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('CurrencyForm', () {
    testWidgets('selecting a different currency calls onCurrencyChanged', (tester) async {
      String? changedTo;

      await pumpApp(
        tester,
        CurrencyForm(
          currentCurrency: 'EUR',
          supportedCurrencies: const ['EUR', 'USD', 'GBP'],
          onCurrencyChanged: (currency) => changedTo = currency,
        ),
      );

      await tester.tap(find.byIcon(Icons.attach_money_rounded));
      await tester.pump();

      expect(changedTo, 'USD');
    });
  });
}
