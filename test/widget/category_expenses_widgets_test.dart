import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/pages/category_expenses/widgets/expense_card.dart';
import 'package:budgly/src/pages/category_expenses/widgets/expense_status_avatar.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/account_view.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/domain/widgets/categories/selector.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/recurrence_selector.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/recurrence_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('ExpenseCard renders pending and recurring states', (tester) async {
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1',
      name: 'Loyer', amount: 850, recurrence: RecurrenceType.monthly,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense,
      date: DateTime(2026, 3, 5),
      isDebited: false,
    );

    await pumpApp(
      tester,
      ExpenseCard(
        occurrence: occurrence,
        currencyCode: 'EUR',
        localeName: 'fr',
        onTap: () {}, onEdit: () {}, onToggleDebited: () {}, onDelete: () {},
      ),
    );

    expect(find.text('Loyer'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) =>
        widget is Text && widget.data != null && widget.data!.contains('850')), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byType(RecurrenceBadge), findsOneWidget);
    expect(find.text('Mensuel'), findsOneWidget);
  });

  testWidgets('ExpenseCard disables edit from quick actions once debited', (tester) async {
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1',
      name: 'Courses', amount: 50, isDebited: true,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense,
      date: DateTime(2026, 3, 5),
      isDebited: true,
    );
    var editCalls = 0;

    await pumpApp(
      tester,
      ExpenseCard(
        occurrence: occurrence,
        currencyCode: 'EUR',
        localeName: 'fr',
        onTap: () {},
        onEdit: () => editCalls++,
        onToggleDebited: () {},
        onDelete: () {},
      ),
    );

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.longPress(find.text('Courses'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsNothing);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(editCalls, 0);
  });

  testWidgets('ExpenseStatusAvatar switches icon with debited state', (tester) async {
    await pumpApp(tester, const ExpenseStatusAvatar(isDebited: false));
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

    await pumpApp(tester, const ExpenseStatusAvatar(isDebited: true));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('RecurrenceSelector exposes all recurrence choices and reports selection', (tester) async {
    var selected = RecurrenceType.none;
    await pumpApp(
      tester,
      RecurrenceSelector(
        selectedRecurrence: selected,
        onRecurrenceChanged: (value) => selected = value,
      ),
    );

    await tester.tap(find.text('Aucune'));
    await tester.pumpAndSettle();
    expect(find.text('Mensuel'), findsOneWidget);
    expect(find.text('Hebdomadaire'), findsOneWidget);
    expect(find.text('Tout les 2 mois'), findsOneWidget);

    final weekly = find.text('Hebdomadaire').last;
    await tester.ensureVisible(weekly);
    await tester.tap(weekly);
    await tester.pumpAndSettle();
    expect(selected, RecurrenceType.weekly);
  });

  testWidgets('AccountSelector compact mode opens accounts and returns selected account', (tester) async {
    final first = Fixtures.account(id: 'a1', name: 'Courant');
    final second = Fixtures.account(id: 'a2', name: 'Épargne');
    Account? selected;

    await pumpApp(
      tester,
      AccountSelector(
        accounts: [first, second],
        selectedAccount: first,
        compact: true,
        onSelect: (value) => selected = value,
      ),
    );

    await tester.tap(find.byType(AccountSelector));
    await tester.pumpAndSettle();
    expect(find.text('Courant'), findsOneWidget);
    expect(find.text('Épargne'), findsOneWidget);

    await tester.tap(find.text('Épargne'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'a2');
  });

  testWidgets('AccountSelector returns empty widget when no valid account exists', (tester) async {
    const accountWithoutId = Account(name: 'Sans ID');
    await pumpApp(
      tester,
      AccountSelector(accounts: [accountWithoutId], onSelect: (_) {}),
    );
    expect(find.byType(AccountSelector), findsOneWidget);
    expect(find.byType(AccountView), findsNothing);
  });

  testWidgets('CategorySelector opens category choices and reports selection', (tester) async {
    final c1 = Fixtures.category(id: 'c1', accountId: 'a1', name: 'Courses');
    final c2 = Fixtures.category(id: 'c2', accountId: 'a1', name: 'Transport');
    Category? selected;

    await pumpApp(
      tester,
      CategorySelector(
        categories: [c1, c2],
        selectedCategory: c1,
        onSelect: (value) => selected = value,
      ),
    );

    await tester.tap(find.byType(CategorySelector));
    await tester.pumpAndSettle();
    expect(find.text('Courses'), findsNWidgets(2));
    expect(find.text('Transport'), findsOneWidget);

    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'c2');
  });
}
