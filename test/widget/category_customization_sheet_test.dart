import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_customization_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

const _iconA = CategoryIcon(
  iconName: 'category_rounded',
  iconCode: 0xe001,
  iconPack: 'MaterialIcons',
  labels: {'en': 'Category', 'fr': 'Catégorie'},
);
const _iconB = CategoryIcon(
  iconName: 'home_rounded',
  iconCode: 0xe002,
  iconPack: 'MaterialIcons',
  labels: {'en': 'Home', 'fr': 'Maison'},
);

Future<void> _openSheet(
  WidgetTester tester, {
  required ValueChanged<CategoryIcon> onIconChanged,
  required ValueChanged<Color> onColorChanged,
}) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showCategoryCustomizationSheet(
          context,
          availableIcons: const [_iconA, _iconB],
          initialIcon: _iconA,
          initialColor: Colors.blue,
          previewBuilder: (context, icon, color) => Icon(icon.toIconData(), color: color),
          onIconChanged: onIconChanged,
          onColorChanged: onColorChanged,
        ),
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('showCategoryCustomizationSheet', () {
    testWidgets('cancelling after browsing a different icon does not commit it', (tester) async {
      CategoryIcon? committedIcon;

      await _openSheet(
        tester,
        onIconChanged: (icon) => committedIcon = icon,
        onColorChanged: (_) {},
      );

      // Browse to a different icon than the initial one.
      await tester.tap(find.byIcon(_iconB.toIconData()));
      await tester.pump();

      // Cancel instead of confirming.
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(
        committedIcon,
        isNull,
        reason: 'browsing an icon without confirming must not commit it, '
            'even after Cancel is tapped',
      );
    });

    testWidgets('confirming commits the last browsed icon', (tester) async {
      CategoryIcon? committedIcon;

      await _openSheet(
        tester,
        onIconChanged: (icon) => committedIcon = icon,
        onColorChanged: (_) {},
      );

      await tester.tap(find.byIcon(_iconB.toIconData()));
      await tester.pump();

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(committedIcon?.iconName, _iconB.iconName);
    });
  });
}
