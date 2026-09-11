import 'package:budgly/src/pages/category_expenses/widgets/swipe_hint_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group('SwipeHintContent', () {
    testWidgets('shows a right-swipe icon when not debited', (tester) async {
      await pumpApp(
        tester,
        const SizedBox(
          width: 300,
          height: 80,
          child: SwipeHintContent(progress: 0.5, isDebited: false),
        ),
      );

      expect(find.byIcon(Icons.swipe_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.swipe_left_rounded), findsNothing);
      expect(find.text('Glissez'), findsOneWidget);
    });

    testWidgets('shows a left-swipe icon when debited', (tester) async {
      await pumpApp(
        tester,
        const SizedBox(
          width: 300,
          height: 80,
          child: SwipeHintContent(progress: 0.5, isDebited: true),
        ),
      );

      expect(find.byIcon(Icons.swipe_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.swipe_right_rounded), findsNothing);
    });

    testWidgets('renders at the start and end of the animation without error', (tester) async {
      await pumpApp(
        tester,
        const SizedBox(
          width: 300,
          height: 80,
          child: SwipeHintContent(progress: 0.0, isDebited: false),
        ),
      );
      expect(tester.takeException(), isNull);

      await pumpApp(
        tester,
        const SizedBox(
          width: 300,
          height: 80,
          child: SwipeHintContent(progress: 1.0, isDebited: false),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
