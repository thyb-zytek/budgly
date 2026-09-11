import 'package:budgly/src/pages/settings/preferences/widgets/theme_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('ThemeForm', () {
    testWidgets('selecting a different theme mode calls onThemeChanged', (tester) async {
      ThemeMode? changedTo;

      await pumpApp(
        tester,
        ThemeForm(
          currentThemeMode: ThemeMode.system,
          onThemeChanged: (mode) => changedTo = mode,
        ),
      );

      await tester.tap(find.text('Sombre'));
      await tester.pump();

      expect(changedTo, ThemeMode.dark);
    });

    testWidgets('tapping the already-selected mode still reports it', (tester) async {
      ThemeMode? changedTo;

      await pumpApp(
        tester,
        ThemeForm(
          currentThemeMode: ThemeMode.light,
          onThemeChanged: (mode) => changedTo = mode,
        ),
      );

      await tester.tap(find.text('Clair'));
      await tester.pump();

      expect(changedTo, ThemeMode.light);
    });
  });
}
