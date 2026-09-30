import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('renders the compact category form without action row', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Loisirs');
    addTearDown(controller.dispose);
    final formKey = GlobalKey<FormState>();
    final icon = Fixtures.categoryIcon();

    await pumpApp(
      tester,
      CategoryForm(
        formKey: formKey,
        nameController: controller,
        initialColor: const Color(0xFF66BB6A),
        initialIcon: icon,
        availableIcons: <CategoryIcon>[icon],
        compact: true,
      ),
    );

    expect(find.text('Loisirs'), findsOneWidget);
    expect(find.text('Valider'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets('submit callback is invoked by the action row', (tester) async {
    final controller = TextEditingController(text: 'Loisirs');
    addTearDown(controller.dispose);
    var submitted = false;
    final icon = Fixtures.categoryIcon();

    await pumpApp(
      tester,
      CategoryForm(
        formKey: GlobalKey<FormState>(),
        nameController: controller,
        initialColor: const Color(0xFF66BB6A),
        initialIcon: icon,
        availableIcons: <CategoryIcon>[icon],
        onSubmit: () => submitted = true,
      ),
    );

    await tester.tap(find.text('Valider'));
    await tester.pump();
    expect(submitted, isTrue);
  });
}
