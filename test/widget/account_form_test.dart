import 'package:budgly/src/shared/domain/widgets/accounts/account_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('renders the compact account form without action row', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Perso');
    addTearDown(controller.dispose);

    await pumpApp(
      tester,
      AccountForm(
        formKey: GlobalKey<FormState>(),
        nameController: controller,
        initialColor: Colors.blue,
        compact: true,
      ),
    );

    expect(find.text('Perso'), findsOneWidget);
    expect(find.text('Valider'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets('full form renders the action row and submits by default', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Perso');
    addTearDown(controller.dispose);
    var submitted = false;

    await pumpApp(
      tester,
      AccountForm(
        formKey: GlobalKey<FormState>(),
        nameController: controller,
        initialColor: Colors.blue,
        onSubmit: () => submitted = true,
      ),
    );

    expect(find.text('Valider'), findsOneWidget);
    await tester.tap(find.text('Valider'));
    await tester.pump();
    expect(submitted, isTrue);
  });

  testWidgets('full form hides its action row when showActions is false', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Perso');
    addTearDown(controller.dispose);

    await pumpApp(
      tester,
      AccountForm(
        formKey: GlobalKey<FormState>(),
        nameController: controller,
        initialColor: Colors.blue,
        showActions: false,
      ),
    );

    expect(find.text('Perso'), findsOneWidget);
    expect(find.text('Valider'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets(
    'full form submits from the keyboard "done" when its action row is hidden',
    (tester) async {
      final controller = TextEditingController(text: 'Perso');
      addTearDown(controller.dispose);
      var submitted = false;

      await pumpApp(
        tester,
        AccountForm(
          formKey: GlobalKey<FormState>(),
          nameController: controller,
          initialColor: Colors.blue,
          onSubmit: () => submitted = true,
          showActions: false,
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Perso');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, isTrue);
    },
  );
}
