import 'package:budgly/src/pages/settings/profile/widgets/change_password_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

Future<void> _pumpSheet(
  WidgetTester tester, {
  required void Function(String oldPassword, String newPassword) onSubmit,
}) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => ChangePasswordSheet.show(context, onSubmit: onSubmit),
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('ChangePasswordSheet', () {
    testWidgets(
      'submitting mismatched passwords keeps the sheet open and does not call onSubmit',
      (tester) async {
        var submitCalls = 0;

        await _pumpSheet(tester, onSubmit: (_, _) => submitCalls++);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Ancien mot de passe'),
          'oldpass1',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Mot de passe'),
          'newpass1',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
          'different',
        );

        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();

        expect(submitCalls, 0);
        // The sheet must still be visible: submitting an invalid form should
        // not silently close it and discard what the user typed.
        expect(find.text('Modifier le mot de passe'), findsOneWidget);
      },
    );

    testWidgets(
      'submitting matching, valid passwords calls onSubmit with both passwords and closes the sheet',
      (tester) async {
        String? capturedOld;
        String? capturedNew;

        await _pumpSheet(
          tester,
          onSubmit: (oldPassword, newPassword) {
            capturedOld = oldPassword;
            capturedNew = newPassword;
          },
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Ancien mot de passe'),
          'oldpass1',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Mot de passe'),
          'newpass1',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
          'newpass1',
        );

        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();

        expect(capturedOld, 'oldpass1');
        expect(capturedNew, 'newpass1');
        expect(find.text('Modifier le mot de passe'), findsNothing);
      },
    );
  });
}
