import 'package:budgly/src/shared/ui/widgets/customization_picker.dart';
import 'package:budgly/src/shared/ui/widgets/tabs/tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group('CustomizationPicker', () {
    testWidgets('shows the first tab by default and switches on tap', (tester) async {
      await pumpApp(
        tester,
        CustomizationPicker(
          title: 'Personnaliser',
          previewWidget: const Icon(Icons.category_rounded),
          tabTitles: [
            TabTitle(icon: Icons.category_rounded, title: 'Icône'),
            TabTitle(icon: Icons.palette_rounded, title: 'Couleur'),
          ],
          tabs: const [
            Text('icon-tab-content'),
            Text('color-tab-content'),
          ],
          onValidate: () {},
          onCancel: () {},
        ),
      );

      expect(find.text('icon-tab-content'), findsOneWidget);
      expect(find.text('color-tab-content'), findsNothing);

      await tester.tap(find.text('Couleur'));
      await tester.pumpAndSettle();

      expect(find.text('color-tab-content'), findsOneWidget);
      expect(find.text('icon-tab-content'), findsNothing);
    });

    testWidgets('calls onValidate and onCancel from the action row', (tester) async {
      var validateCalls = 0;
      var cancelCalls = 0;

      await pumpApp(
        tester,
        CustomizationPicker(
          title: 'Personnaliser',
          previewWidget: const Icon(Icons.category_rounded),
          tabTitles: [
            TabTitle(icon: Icons.category_rounded, title: 'Icône'),
            TabTitle(icon: Icons.palette_rounded, title: 'Couleur'),
          ],
          tabs: const [SizedBox.shrink(), SizedBox.shrink()],
          onValidate: () => validateCalls++,
          onCancel: () => cancelCalls++,
        ),
      );

      await tester.tap(find.text('Valider'));
      await tester.pump();
      expect(validateCalls, 1);

      await tester.tap(find.text('Annuler'));
      await tester.pump();
      expect(cancelCalls, 1);
    });
  });
}
