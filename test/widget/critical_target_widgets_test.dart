import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/pages/category_expenses/widgets/swipe_action_background.dart';
import 'package:budgly/src/pages/overview/ui_state.dart';
import 'package:budgly/src/pages/overview/widgets/donut_chart.dart';
import 'package:budgly/src/pages/overview/widgets/summary_card.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/end_date_field.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_editor_sheet.dart';
import 'package:budgly/src/shared/domain/widgets/user/details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';
import '../helpers/pump_app.dart';

void main() {
  final category = Fixtures.category(id: 'food', accountId: 'a1');
  final summary = CategoryExpenseSummary(
    category: category,
    total: 80,
    debited: 50,
    undebited: 30,
    undebitedCount: 2,
  );

  test(
    'revenue summary distinguishes direct, inherited, and absent revenue',
    () {
      const direct = RevenueSummary(revenue: 1200, inheritedRevenue: 900);
      const inherited = RevenueSummary(revenue: 0, inheritedRevenue: 900);
      const absent = RevenueSummary(revenue: 0, inheritedRevenue: null);

      expect(direct.hasRevenue, isTrue);
      expect(direct.isEstimated, isFalse);
      expect(direct.effectiveRevenue, 1200);
      expect(inherited.hasRevenue, isFalse);
      expect(inherited.isEstimated, isTrue);
      expect(inherited.effectiveRevenue, 900);
      expect(absent.isEstimated, isFalse);
      expect(absent.effectiveRevenue, 0);
    },
  );

  testWidgets(
    'end date field suggests recurrence end and clears an explicit date',
    (tester) async {
      var cleared = 0;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => buildEndDateField(
            context,
            endDate: DateTime(2026, 5, 5),
            recurrence: RecurrenceType.monthly,
            minimumDate: DateTime(2026, 3, 31, 23),
            localeName: 'fr_FR',
            onDateChanged: (_) {},
            onCleared: () => cleared++,
          ),
        ),
      );
      expect(find.byIcon(Icons.event_busy_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(cleared, 1);

      await pumpApp(
        tester,
        Builder(
          builder: (context) => buildEndDateField(
            context,
            endDate: null,
            recurrence: RecurrenceType.none,
            minimumDate: DateTime(2026, 3, 31),
            localeName: 'fr_FR',
            onDateChanged: (_) {},
            onCleared: () => cleared++,
          ),
        ),
      );
      expect(find.text('Ajouter une date de fin'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    },
  );

  testWidgets('donut chart handles empty and populated categories', (
    tester,
  ) async {
    CategoryExpenseSummary? selected;
    await pumpApp(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CategoryDonutChart(summaries: [], size: 96),
          CategoryDonutChart(
            summaries: [summary],
            size: 120,
            referenceTotal: 200,
            centerChild: const Text('Total'),
            onCategoryTap: (value) => selected = value,
          ),
        ],
      ),
    );
    expect(find.text('Total'), findsOneWidget);
    await tester.tapAt(
      tester.getCenter(find.byType(CategoryDonutChart).last) +
          const Offset(0, -49),
    );
    expect(selected, same(summary));
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester, CategoryDonutChart(summaries: [summary], size: 96));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'overview summary shows financial totals in expanded and compact modes',
    (tester) async {
      final account = Fixtures.account(id: 'a1');
      Widget card({required bool compact}) => OverviewSummaryCard(
        accounts: [account],
        account: account,
        period: const Period(year: 2026, month: 3),
        categorySummaries: [summary],
        revenue: const RevenueSummary(revenue: 1200, inheritedRevenue: null),
        formatAmount: (value) => '${value.toStringAsFixed(0)} €',
        onSelectAccount: (_) {},
        compact: compact,
      );

      await pumpApp(tester, card(compact: false));
      expect(find.text('1200 €'), findsOneWidget);
      expect(find.text('80 €'), findsOneWidget);
      await pumpApp(tester, card(compact: true));
      expect(find.text('1200 €'), findsOneWidget);
      expect(find.text('80 €'), findsOneWidget);
    },
  );

  testWidgets('expense editor validates before saving and reports failure', (
    tester,
  ) async {
    final name = TextEditingController(text: 'Loyer');
    final amount = TextEditingController(text: '850');
    addTearDown(name.dispose);
    addTearDown(amount.dispose);
    var saves = 0;
    var before = 0;
    var errors = 0;
    final data = ExpenseEditingData(
      debitDate: DateTime(2026, 3, 1),
      recurrence: RecurrenceType.none,
    );

    await pumpApp(
      tester,
      ExpenseEditorSheet(
        listenable: Listenable.merge([name, amount]),
        editingData: data,
        nameController: name,
        amountController: amount,
        title: 'Modifier dépense',
        currencyCode: 'EUR',
        localeName: 'fr_FR',
        validate: (_) => null,
        onBeforeSubmit: () async {
          before++;
          return true;
        },
        onSubmit: () async {
          saves++;
          return false;
        },
        submitFailureMessage: 'Échec de sauvegarde',
        onDateChanged: (_) {},
        onRecurrenceChanged: (_) {},
        onEndDateChanged: (_) {},
        onEndDateCleared: () {},
        onToggleAdvanced: () {},
        onSubmitSuccess: () => errors++,
      ),
    );
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(before, 1);
    expect(saves, 1);
    expect(find.text('Échec de sauvegarde'), findsOneWidget);
    expect(errors, 0);
  });

  testWidgets('snackbar exposes close action and swipe background alignment', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SwipeActionBackground(
            alignment: Alignment.centerLeft,
            icon: Icons.delete,
            color: Colors.red,
            foregroundColor: Colors.white,
          ),
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSnackBar(
                context,
                message: 'Enregistré',
                type: SnackBarType.success,
              ),
              child: const Text('Afficher'),
            ),
          ),
        ],
      ),
      settle: false,
    );
    expect(find.byIcon(Icons.delete), findsOneWidget);
    await tester.tap(find.text('Afficher'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Enregistré'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Enregistré'), findsNothing);
  });

  testWidgets('user details saves edited name and restores cancelled edits', (
    tester,
  ) async {
    final changedNames = <String>[];
    final createdAt = DateTime(2024, 2, 3);
    final user = User(
      id: 'u1',
      email: 'alex@example.com',
      profile: UserProfile(
        id: 'u1',
        email: 'alex@example.com',
        fullName: 'Alex',
        createdAt: createdAt,
      ),
    );
    await pumpApp(
      tester,
      UserDetails(user: user, onChangeName: changedNames.add),
    );
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);
    expect(find.text('03/02/2024'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Alexandre');
    await tester.tap(find.byIcon(Icons.check_circle_rounded));
    await tester.pump();
    expect(changedNames, ['Alexandre']);
    // UserDetails reports the proposed name; its parent owns the User model
    // and decides when to supply the updated profile back to this widget.
    expect(find.text('Alex'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Annulé');
    await tester.tap(find.byIcon(Icons.cancel_rounded));
    await tester.pump();
    expect(find.text('Alex'), findsOneWidget);
    expect(changedNames, ['Alexandre']);
  });
}
