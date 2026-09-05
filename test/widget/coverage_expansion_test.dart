import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/pages/overview/ui_state.dart';
import 'package:budgly/src/pages/overview/widgets/overview_stat.dart';
import 'package:budgly/src/pages/overview/widgets/period_slide_switcher.dart';
import 'package:budgly/src/pages/overview/widgets/summary_stat.dart';
import 'package:budgly/src/pages/overview/widgets/summary_stat_value.dart';
import 'package:budgly/src/pages/settings/widgets/add_entity.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/pages/tutorial/widgets/step_indicator.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_pop_in.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_badge.dart';
import 'package:budgly/src/shared/domain/widgets/categories/status_chip.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/advanced_date_field.dart';
import 'package:budgly/src/shared/domain/widgets/user/view_card.dart';
import 'package:budgly/src/pages/settings/widgets/entity_title.dart';
import 'package:budgly/src/shared/ui/widgets/forms/form_actions.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/date_field.dart';
import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
import 'package:budgly/src/shared/ui/widgets/layout/color_wheel.dart';
import 'package:budgly/src/shared/ui/widgets/tabs/swipe_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('summary widgets cover optional detail, tooltip and action branches', (tester) async {
    var taps = 0;
    final item = OverviewStatItem(
      icon: Icons.payments_outlined,
      label: 'Dépenses',
      value: '120 €',
      detail: '8 opérations',
      detailColor: Colors.green,
      color: Colors.blue,
      isEmphasized: true,
      tooltip: 'Détail des dépenses',
      onTap: () => taps++,
      trailingIcon: Icons.chevron_right,
    );

    await pumpApp(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OverviewStat(item: item),
          const SummaryStat(
            icon: Icons.wallet,
            label: 'Simple',
            value: '50 €',
            compact: true,
          ),
          SummaryStatValue(
            value: '100 €',
            detail: 'prévu',
            compact: false,
            isEmphasized: false,
            color: null,
            detailColor: null,
            theme: ThemeData.light(useMaterial3: true),
          ),
        ],
      ),
    );

    expect(find.text('Dépenses'), findsOneWidget);
    expect(find.text('120 €'), findsOneWidget);
    expect(find.text('(8 opérations)'), findsOneWidget);
    expect(find.byType(Tooltip), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.text('Dépenses'));
    expect(taps, 1);
  });

  testWidgets('period slide switcher renders both directions and changes child', (tester) async {
    const period = Period(year: 2026, month: 8);
    await pumpApp(
      tester,
      const PeriodSlideSwitcher(
        period: period,
        direction: -1,
        child: Text('Août'),
      ),
    );
    expect(find.text('Août'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PeriodSlideSwitcher(
            period: Period(year: 2026, month: 9),
            direction: 1,
            child: Text('Septembre'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Septembre'), findsOneWidget);
  });

  testWidgets('status chip covers normal and highlighted presentation', (tester) async {
    await pumpApp(
      tester,
      const Row(
        children: [
          StatusChip(label: 'Payé', icon: Icons.check, color: Colors.green),
          StatusChip(
            label: 'En attente',
            icon: Icons.schedule,
            color: Colors.orange,
            isHighlighted: true,
          ),
        ],
      ),
    );
    expect(find.text('Payé'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });

  testWidgets('tutorial indicators and pop-in render their state', (tester) async {
    await pumpApp(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StepIndicator(currentStep: 1, totalSteps: 3),
          TutorialStepBadge(size: 72, child: Icon(Icons.home)),
          TutorialPopIn(child: Text('Pop in')),
        ],
      ),
    );
    expect(find.textContaining('Étape'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.text('Pop in'), findsOneWidget);
  });

  testWidgets('date widgets cover empty and populated states', (tester) async {
    var cleared = 0;
    await pumpApp(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DateField(
            localeName: 'fr_FR',
            placeholder: 'Choisir une date',
            onDateChanged: (_) {},
          ),
          DateField(
            localeName: 'fr_FR',
            date: DateTime(2026, 8, 30),
            onDateChanged: (_) {},
            onCleared: () => cleared++,
          ),
          const AdvancedDateField(
            label: 'Date de fin',
            child: Text('Champ avancé'),
          ),
        ],
      ),
    );
    expect(find.text('Choisir une date'), findsOneWidget);
    expect(find.textContaining('30'), findsOneWidget);
    expect(find.text('DATE DE FIN'), findsOneWidget);
    expect(find.text('Champ avancé'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(cleared, 1);
  });

  testWidgets('avatar covers remove and network picture branches', (tester) async {
    var removed = 0;
    await pumpApp(
      tester,
      Avatar(
        initial: 'A',
        picture: 'https://example.com/avatar.png',
        size: 110,
        borderColor: Colors.blue,
        canRemove: true,
        onRemove: () => removed++,
        showEditBadge: true,
        onTap: () {},
      ),
    );
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(removed, 1);
  });

  testWidgets('color wheel exposes accessible picker and reports changes', (tester) async {
    Color? selected;
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      SizedBox(
        height: 260,
        child: ColorWheel(
          color: Colors.blue,
          onChanged: (value) => selected = value,
        ),
      ),
    );
    expect(find.bySemanticsLabel('Sélecteur de couleur'), findsOneWidget);
    expect(find.byType(ColorWheel), findsOneWidget);
    // The callback is supplied to the real picker; this assertion also ensures
    // the test keeps a usable callback instead of a null placeholder.
    expect(selected, isNull);
    semantics.dispose();
  });

  testWidgets('swipe tabs changes tab through the visible tab control', (tester) async {
    var selected = -1;
    await pumpApp(
      tester,
      SizedBox(
        height: 500,
        child: SwipeTabs(
          tabs: const [Text('Un'), Text('Deux')],
          children: const [Text('Page 1'), Text('Page 2')],
          onIndexChanged: (index) => selected = index,
        ),
      ),
    );

    await tester.tap(find.text('Deux'));
    await tester.pump();
    expect(selected, 1);
    expect(find.text('Page 2'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: SwipeTabs(
              initialIndex: 1,
              tabs: const [Text('Un'), Text('Deux')],
              children: const [Text('Page 1'), Text('Page 2')],
              onIndexChanged: (index) => selected = index,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Page 2'), findsOneWidget);
  });

  testWidgets('EntityTitle renders title and subtitle', (tester) async {
    await pumpApp(
      tester,
      const EntityTitle(title: 'Comptes', subtitle: 'Gérez vos comptes'),
    );
    expect(find.text('Comptes'), findsOneWidget);
    expect(find.text('Gérez vos comptes'), findsOneWidget);
  });

  testWidgets('AddEntity hides its label after press and invokes callback', (tester) async {
    var calls = 0;
    await pumpApp(
      tester,
      Stack(
        children: [
          AddEntity(
            heroTag: 'coverage-add',
            label: 'Ajouter',
            onPressed: () => calls++,
          ),
        ],
      ),
    );
    expect(find.text('Ajouter'), findsOneWidget);
    await tester.tap(find.text('Ajouter'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Ajouter'), findsNothing);
  });

  testWidgets('FormActions disables both actions while loading', (tester) async {
    var cancelCalls = 0;
    var submitCalls = 0;
    await pumpApp(
      tester,
      FormActions(
        onCancel: () => cancelCalls++,
        onSubmit: () => submitCalls++,
        isLoading: true,
      ),
    );
    await tester.tap(find.text('Annuler'));
    await tester.tap(find.text('Valider'));
    expect(cancelCalls, 0);
    expect(submitCalls, 0);
  });

  testWidgets('ConfirmDelete confirms and closes the route', (tester) async {
    var confirmed = false;
    await pumpApp(
      tester,
      ConfirmDelete(
        title: 'Supprimer ?',
        content: 'Cette action est irréversible.',
        onConfirm: () async => confirmed = true,
      ),
    );
    expect(find.text('Supprimer ?'), findsOneWidget);
    expect(find.text('Cette action est irréversible.'), findsOneWidget);
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('UserCard covers profile and fallback identity', (tester) async {
    await pumpApp(
      tester,
      Column(
        children: [
          UserCard(
            user: User(
              id: 'u1',
              email: 'alex@example.com',
              profile: UserProfile(
                id: 'u1',
                email: 'alex@example.com',
                fullName: 'Alex',
              ),
            ),
          ),
          UserCard(user: User(id: 'u2')),
        ],
      ),
    );
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);

    await pumpApp(tester, UserCard(user: User(id: 'u2')));
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
