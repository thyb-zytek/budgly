import 'package:budgly/src/pages/category_expenses/widgets/swipe_hint_content.dart';
import 'package:budgly/src/pages/category_expenses/widgets/swipe_hint_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group('SwipeHintWrapper', () {
    testWidgets('renders its child and the hint overlay, and stop() removes the overlay', (tester) async {
      final key = GlobalKey<SwipeHintWrapperState>();

      await pumpApp(
        tester,
        SwipeHintWrapper(
          key: key,
          isDebited: false,
          child: const Text('row content'),
        ),
      );

      expect(find.text('row content'), findsOneWidget);
      expect(find.byType(SwipeHintContent), findsOneWidget);

      key.currentState!.stop();
      await tester.pump();

      expect(find.byType(SwipeHintContent), findsNothing);
      // The child itself must stay, only the hint overlay is removed.
      expect(find.text('row content'), findsOneWidget);
    });

    testWidgets('calling stop() twice does not throw', (tester) async {
      final key = GlobalKey<SwipeHintWrapperState>();

      await pumpApp(
        tester,
        SwipeHintWrapper(
          key: key,
          isDebited: true,
          child: const SizedBox(),
        ),
      );

      key.currentState!.stop();
      key.currentState!.stop();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
