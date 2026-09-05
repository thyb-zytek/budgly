import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_category_tile.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_badge.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:budgly/src/pages/tutorial/widgets/welcome_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('welcome step renders and advances', (tester) async {
    var next = 0;
    await pumpApp(tester, WelcomeStep(onNext: () => next++));
    expect(find.text('Bienvenue sur Budgly !'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    await tester.tap(find.text('Commencer'));
    expect(next, 1);
  });

  testWidgets('tutorial step scaffold renders optional badge, content and secondary action', (tester) async {
    var primary = 0;
    var secondary = 0;
    await pumpApp(
      tester,
      TutorialStepScaffold(
        badge: const Icon(Icons.savings),
        title: 'Étape',
        subtitle: 'Description',
        content: const Text('Contenu'),
        primaryAction: FilledButton(onPressed: () => primary++, child: const Text('Suivant')),
        secondaryAction: TextButton(onPressed: () => secondary++, child: const Text('Retour')),
      ),
    );
    expect(find.byIcon(Icons.savings), findsOneWidget);
    expect(find.text('Étape'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Contenu'), findsOneWidget);
    await tester.tap(find.text('Suivant'));
    await tester.tap(find.text('Retour'));
    expect(primary, 1);
    expect(secondary, 1);
  });

  testWidgets('tutorial category tile renders fallback and icon variants', (tester) async {
    var deletes = 0;
    final noIcon = Category(
      id: 'c1',
      name: 'Autre',
      color: Colors.blue,
      accountId: 'a1',
    );
    await pumpApp(tester, TutorialCategoryTile(category: noIcon, onDelete: () => deletes++));
    expect(find.text('Autre'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_rounded));
    expect(deletes, 1);

    final withIcon = Category(
      id: 'c2',
      name: 'Alimentation',
      color: Colors.orange,
      icon: const CategoryIcon(
        iconName: 'home',
        iconCode: 0xe88a,
        iconPack: 'MaterialIcons',
        labels: {'fr': 'Maison'},
      ),
      accountId: 'a1',
    );
    await pumpApp(tester, TutorialCategoryTile(category: withIcon, onDelete: () {}));
    expect(find.text('Alimentation'), findsOneWidget);
  });

  testWidgets('tutorial step badge renders custom size and child', (tester) async {
    await pumpApp(
      tester,
      const TutorialStepBadge(size: 96, child: Icon(Icons.home)),
    );
    expect(find.byIcon(Icons.home), findsOneWidget);
    final badge = tester.widget<TutorialStepBadge>(find.byType(TutorialStepBadge));
    expect(badge.size, 96);
  });
}
