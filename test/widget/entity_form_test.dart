import 'package:budgly/src/shared/ui/widgets/forms/entity_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

Future<GlobalKey<FormState>> _pumpForm(
  WidgetTester tester, {
  required TextEditingController controller,
  required VoidCallback onSubmit,
  required VoidCallback onCancel,
}) async {
  final formKey = GlobalKey<FormState>();
  await pumpApp(
    tester,
    EntityForm(
      formKey: formKey,
      leadingWidget: const Icon(Icons.account_balance_wallet_rounded),
      nameController: controller,
      labelText: 'Nom',
      onSubmit: onSubmit,
      onCancel: onCancel,
    ),
  );
  return formKey;
}

void main() {
  group('EntityForm', () {
    testWidgets('does not call onSubmit when the name is empty', (tester) async {
      var submitCalls = 0;
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pumpForm(
        tester,
        controller: controller,
        onSubmit: () => submitCalls++,
        onCancel: () {},
      );

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(submitCalls, 0);
      expect(find.text('Le nom est obligatoire.'), findsOneWidget);
    });

    testWidgets('calls onSubmit when the name is filled in', (tester) async {
      var submitCalls = 0;
      final controller = TextEditingController(text: 'Loyer');
      addTearDown(controller.dispose);

      await _pumpForm(
        tester,
        controller: controller,
        onSubmit: () => submitCalls++,
        onCancel: () {},
      );

      await tester.tap(find.text('Valider'));
      await tester.pump();

      expect(submitCalls, 1);
    });

    testWidgets('calls onCancel even when the name is empty (no validation gate)', (tester) async {
      var cancelCalls = 0;
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pumpForm(
        tester,
        controller: controller,
        onSubmit: () {},
        onCancel: () => cancelCalls++,
      );

      await tester.tap(find.text('Annuler'));
      await tester.pump();

      expect(cancelCalls, 1);
    });
  });
}
