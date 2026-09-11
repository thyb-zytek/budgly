import 'package:budgly/src/shared/domain/widgets/accounts/avatar_customization_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  String? initialPicture,
  required ValueChanged<String?> onPictureChanged,
  required ValueChanged<Color> onColorChanged,
}) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showAvatarCustomizationSheet(
          context,
          initial: 'A',
          initialPicture: initialPicture,
          initialColor: Colors.blue,
          pickImage: () async => '/tmp/fake-picture.jpg',
          onPictureChanged: onPictureChanged,
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
  group('showAvatarCustomizationSheet', () {
    testWidgets('cancelling after picking a new picture does not commit it', (tester) async {
      String? committedPicture;

      await _openSheet(
        tester,
        onPictureChanged: (picture) => committedPicture = picture,
        onColorChanged: (_) {},
      );

      await tester.tap(find.text('Sélectionner une image'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(
        committedPicture,
        isNull,
        reason: 'picking a picture without confirming must not commit it, '
            'even after Cancel is tapped',
      );
    });

    testWidgets('confirming commits the picked picture', (tester) async {
      String? committedPicture;

      await _openSheet(
        tester,
        onPictureChanged: (picture) => committedPicture = picture,
        onColorChanged: (_) {},
      );

      await tester.tap(find.text('Sélectionner une image'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(committedPicture, '/tmp/fake-picture.jpg');
    });

    testWidgets('cancelling after removing the picture does not commit the removal', (tester) async {
      String? committedPicture = 'not-called';

      await _openSheet(
        tester,
        initialPicture: '/tmp/existing.jpg',
        onPictureChanged: (picture) => committedPicture = picture,
        onColorChanged: (_) {},
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(committedPicture, 'not-called');
    });
  });
}
