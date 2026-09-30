import 'package:budgly/src/state/action_status.dart';
import 'package:budgly/src/pages/overview/revenue_provider.dart';
import 'package:budgly/src/pages/overview/widgets/revenue_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

RevenueState _state({double revenue = 0, double? inheritedRevenue}) =>
    RevenueState(
      revenue: revenue,
      inheritedRevenue: inheritedRevenue,
      isLoaded: true,
      showEditor: true,
      status: const ActionStatus.idle(),
    );

void main() {
  testWidgets('starts blank when no revenue is available', (tester) async {
    await pumpApp(
      tester,
      RevenueForm(
        currencyCode: 'EUR',
        state: _state(),
        onClose: () {},
        onSave: (_) async {},
      ),
    );
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('pre-fills inherited revenue', (tester) async {
    await pumpApp(
      tester,
      RevenueForm(
        currencyCode: 'EUR',
        state: _state(inheritedRevenue: 1500),
        onClose: () {},
        onSave: (_) async {},
      ),
    );
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, '1500');
    expect(
      find.text(
        'Aucun revenu défini pour cette période — le plus récent est utilisé comme estimation',
      ),
      findsOneWidget,
    );
  });

  testWidgets('saving delegates the parsed value and closes', (tester) async {
    double? saved;
    var closed = false;
    await pumpApp(
      tester,
      RevenueForm(
        currencyCode: 'EUR',
        state: _state(),
        onClose: () => closed = true,
        onSave: (value) async => saved = value,
      ),
    );
    await tester.enterText(find.byType(TextFormField), '2000');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(saved, 2000);
    expect(closed, isTrue);
  });

  testWidgets('blank value is saved as zero', (tester) async {
    double? saved;
    await pumpApp(
      tester,
      RevenueForm(
        currencyCode: 'EUR',
        state: _state(),
        onClose: () {},
        onSave: (value) async => saved = value,
      ),
    );
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(saved, 0);
  });
}
