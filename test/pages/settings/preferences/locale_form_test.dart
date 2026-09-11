import 'package:budgly/src/pages/settings/preferences/widgets/locale_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('LocaleForm', () {
    testWidgets('selecting the other locale calls onLocaleChanged', (tester) async {
      Locale? changedTo;

      await pumpApp(
        tester,
        LocaleForm(
          currentLocale: const Locale('fr'),
          onLocaleChanged: (locale) => changedTo = locale,
        ),
      );

      // The closed selector shows the current locale ('FR'); tapping it
      // opens the popup menu with both options.
      await tester.tap(find.text('FR'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();

      expect(changedTo, const Locale('en'));
    });
  });
}
