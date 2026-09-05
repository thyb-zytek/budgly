import 'package:budgly/src/shared/ui/widgets/inputs/currency_input.dart';
import 'package:budgly/src/shared/ui/widgets/selector.dart';
import 'package:budgly/src/shared/ui/widgets/layout/budgly_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group('Forms & dropdowns', () {
    testWidgets('CurrencyInput affiche et gère saisie', (tester) async {
      final controller = TextEditingController(text: '12,50');
      await pumpApp(
        tester,
        CurrencyInput(controller: controller, currencyCode: 'EUR', labelText: 'Montant'),
      );
      expect(find.text('Montant'), findsOneWidget);
      // EUR icon via currency extension (not text EUR)
      expect(find.byType(CurrencyInput), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '25,00');
      await tester.pump();
      expect(controller.text, '25,00');
    });

    testWidgets('Selector affiche options et sélection', (tester) async {
      String? selected = 'a';
      await pumpApp(
        tester,
        Selector<String>(
          selectedItem: selected,
          items: const ['a', 'b', 'c'],
          itemBuilder: (context, v) => Text(v.toUpperCase()),
          onSelect: (v) => selected = v,
        ),
      );
      expect(find.text('A'), findsOneWidget);
      await tester.tap(find.byType(Selector<String>));
      await tester.pumpAndSettle();
      // dropdown opens; select b
      await tester.tap(find.text('B').last);
      await tester.pumpAndSettle();
      expect(selected, 'b');
    });

    testWidgets('Selector responsive: mobile 360 vs tablet 768', (tester) async {
      for (final size in [const Size(360, 740), const Size(768, 1024)]) {
        String? sel = 'a';
        await pumpApp(
          tester,
          Selector<String>(
            selectedItem: sel,
            items: const ['a', 'b'],
            itemBuilder: (context, v) => Text(v),
            onSelect: (v) => sel = v,
          ),
          size: size,
        );
        expect(find.byType(Selector<String>), findsOneWidget);
      }
    });

    testWidgets('BudglyFab affiche label étendu au premier usage', (tester) async {
      await pumpApp(
        tester,
        BudglyFab(label: 'Nouvelle dépense', onPressed: () {}, heroTag: 'fab-test-1'),
      );
      expect(find.text('Nouvelle dépense'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('TextFormField validation requis', (tester) async {
      final key = GlobalKey<FormState>();
      final controller = TextEditingController();
      await pumpApp(
        tester,
        Form(
          key: key,
          child: TextFormField(
            controller: controller,
            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      controller.text = 'Hello';
      await tester.pump();
      expect(key.currentState!.validate(), isTrue);
    });

    testWidgets('Loading indicator affiché', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator()))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Dialog confirmation suppression', (tester) async {
      await pumpApp(
        tester,
        Builder(builder: (context) => ElevatedButton(onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Supprimer ?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))])), child: const Text('Ouvrir'))),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer ?'), findsNothing);
    });

    testWidgets('BottomSheet expense quick actions', (tester) async {
      await pumpApp(
        tester,
        Builder(builder: (context) => ElevatedButton(onPressed: () => showModalBottomSheet(context: context, builder: (_) => const SizedBox(height: 200, child: Text('Actions'))), child: const Text('Sheet'))),
      );
      await tester.tap(find.text('Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Actions'), findsOneWidget);
    });
  });
}
