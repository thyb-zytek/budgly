import 'package:budgly/src/pages/tutorial/tutorial_provider.dart';
import 'package:budgly/src/pages/tutorial/widgets/creation_recap.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('shows the account name and category count', (tester) async {
    const state = TutorialState();
    await pumpApp(
      tester,
      const CreationRecap(state: state, accountName: 'Compte principal'),
    );
    expect(find.text('Compte principal'), findsOneWidget);
  });
}
