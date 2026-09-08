import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/undebited_expenses_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/undebited_expenses_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_app.dart';

class FakeWidgetExpensesService extends ExpensesService {
  List<Expense> accountExpenses = const [];
  final List<(Expense, DateTime, DateTime, bool)> moves = [];
  final List<(Expense, DateTime)> marks = [];

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async => accountExpenses;

  @override
  Future<Expense> markOccurrenceDebited(Expense expense, DateTime date) async {
    marks.add((expense, date));
    accountExpenses = accountExpenses.where((e) => e.id != expense.id).toList();
    return expense;
  }

  @override
  Future<Expense> moveOccurrenceToDate(
    Expense expense,
    DateTime occurrenceDate,
    DateTime targetDate, {
    required bool markDebited,
  }) async {
    moves.add((expense, occurrenceDate, targetDate, markDebited));
    accountExpenses = accountExpenses.where((e) => e.id != expense.id).toList();
    return expense;
  }
}

Expense expense({
  required String id,
  required String name,
  required double amount,
  required DateTime debitDate,
}) => Expense(
      id: id,
      accountId: 'account-1',
      categoryId: 'category-1',
      name: name,
      amount: amount,
      debitDate: debitDate,
    );

Future<UndebitedExpensesService> readyService(
  FakeWidgetExpensesService expenses, {
  String currency = 'EUR',
}) async {
  final service = UndebitedExpensesService(
    expensesService: expenses,
    localCache: LocalCache(),
  );
  await service.refresh(
    accountId: 'account-1',
    current: const Period(year: 2026, month: 9),
    showImmediately: true,
  );
  return service;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('banner renders title, subtitle and action when pending exists', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
      ];
    final service = await readyService(expenses);

    await pumpApp(
      tester,
      UndebitedExpensesBanner(
        service: service,
        currencyCode: 'EUR',
        localeName: 'fr',
      ),
    );

    expect(find.text('1 dépense non débitée'), findsOneWidget);
    expect(
      find.text(
        'Ces dépenses proviennent des mois précédents et n\'ont pas encore été débitées.',
      ),
      findsOneWidget,
    );
    expect(find.text('Gérer les dépenses'), findsOneWidget);
    expect(service.shouldShow, isTrue);

    service.dispose();
    expenses.dispose();
  });

  testWidgets('banner is empty when there is nothing pending', (tester) async {
    final expenses = FakeWidgetExpensesService();
    final service = await readyService(expenses);

    await pumpApp(
      tester,
      UndebitedExpensesBanner(
        service: service,
        currencyCode: 'EUR',
        localeName: 'fr',
      ),
    );

    expect(find.byType(UndebitedExpensesBanner), findsOneWidget);
    expect(find.text('Gérer les dépenses'), findsNothing);

    service.dispose();
    expenses.dispose();
  });

  testWidgets('dismiss button hides the banner', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
      ];
    final service = await readyService(expenses);

    await pumpApp(
      tester,
      UndebitedExpensesBanner(
        service: service,
        currencyCode: 'EUR',
        localeName: 'fr',
      ),
    );
    expect(find.text('Gérer les dépenses'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('Gérer les dépenses'), findsNothing);

    service.dispose();
    expenses.dispose();
  });

testWidgets('opening the sheet shows total, groups by period and full dates', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Août long', amount: 100, debitDate: DateTime(2026, 8, 20)),
        expense(id: 'e2', name: 'Juillet x', amount: 50, debitDate: DateTime(2026, 7, 10)),
        expense(id: 'e3', name: 'Juin y', amount: 25, debitDate: DateTime(2026, 6, 1)),
      ];
    final service = await readyService(expenses);

    await pumpApp(
      tester,
      UndebitedExpensesBanner(
        service: service,
        currencyCode: 'EUR',
        localeName: 'fr',
      ),
      size: const Size(400, 1500),
    );

    await tester.tap(find.text('Gérer les dépenses'));
    await tester.pumpAndSettle();

    // Header: title, subtitle and total on the right.
    expect(find.text('Dépenses à traiter'), findsOneWidget);
    expect(find.text('3 dépense(s) en attente'), findsOneWidget);
    expect(find.textContaining('175'), findsOneWidget);

    // Period separators.
    expect(find.text('Juin 2026'), findsOneWidget);
    expect(find.text('Juillet 2026'), findsOneWidget);
    expect(find.text('Août 2026'), findsOneWidget);

    // Full dates displayed on each card.
    expect(find.text('1 juin 2026'), findsOneWidget);
    expect(find.text('10 juillet 2026'), findsOneWidget);
    expect(find.text('20 août 2026'), findsOneWidget);

    // Ascending order: Juin first, Août last.
    final juinY = tester.getTopLeft(find.text('Juin 2026')).dy;
    final juilletY = tester.getTopLeft(find.text('Juillet 2026')).dy;
    final aoutY = tester.getTopLeft(find.text('Août 2026')).dy;
    expect(juinY, lessThan(juilletY));
    expect(juilletY, lessThan(aoutY));

    service.dispose();
    expenses.dispose();
  });

  testWidgets('carry action moves an occurrence to the current period', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
      ];
    final service = await readyService(expenses);

    await pumpApp(
      tester,
      UndebitedExpensesBanner(
        service: service,
        currencyCode: 'EUR',
        localeName: 'fr',
      ),
    );
    await tester.tap(find.text('Gérer les dépenses'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Reporter vers'));
    await tester.pumpAndSettle();

    expect(expenses.moves, hasLength(1));
    expect(expenses.moves.single.$3, DateTime(2026, 9, 1));
    expect(expenses.moves.single.$4, isFalse);

    service.dispose();
    expenses.dispose();
  });

  testWidgets('debit on original period marks the historical occurrence', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
      ];
    final service = await readyService(expenses);

    await pumpApp(
      tester,
      UndebitedExpensesBanner(
        service: service,
        currencyCode: 'EUR',
        localeName: 'fr',
      ),
    );
    await tester.tap(find.text('Gérer les dépenses'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Débiter sur'));
    await tester.pumpAndSettle();

    expect(expenses.marks, hasLength(1));
    expect(expenses.marks.single.$2, DateTime(2026, 8, 5));

    service.dispose();
    expenses.dispose();
  });

  testWidgets('debit now moves and debits the occurrence on the current period', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
      ];
    final service = await readyService(expenses);

    await pumpApp(
      tester,
      UndebitedExpensesBanner(
        service: service,
        currencyCode: 'EUR',
        localeName: 'fr',
      ),
    );
    await tester.tap(find.text('Gérer les dépenses'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Débiter en'));
    await tester.pumpAndSettle();

    expect(expenses.moves, hasLength(1));
    expect(expenses.moves.single.$3, DateTime(2026, 9, 1));
    expect(expenses.moves.single.$4, isTrue);

    service.dispose();
    expenses.dispose();
  });

  testWidgets('handling the last occurrence closes the sheet', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
      ];
    final service = await readyService(expenses);

    await pumpApp(
      tester,
      UndebitedExpensesBanner(
        service: service,
        currencyCode: 'EUR',
        localeName: 'fr',
      ),
    );
    await tester.tap(find.text('Gérer les dépenses'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Reporter vers'));
    await tester.pumpAndSettle();

    expect(find.text('Dépenses à traiter'), findsNothing);

    service.dispose();
    expenses.dispose();
  });

  testWidgets('action buttons target the origin and current periods by name', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
      ];
    final service = await readyService(expenses);

    await pumpApp(
      tester,
      UndebitedExpensesBanner(
        service: service,
        currencyCode: 'EUR',
        localeName: 'fr',
      ),
    );
    await tester.tap(find.text('Gérer les dépenses'));
    await tester.pumpAndSettle();

    expect(find.text('Reporter vers Septembre 2026'), findsOneWidget);
    expect(find.text('Débiter sur Août 2026'), findsOneWidget);
    expect(find.text('Débiter en Septembre 2026'), findsOneWidget);

    service.dispose();
    expenses.dispose();
  });

  testWidgets('sheet amounts always honor the profile decimal places', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
      ];
    final service = await readyService(expenses);

    await pumpApp(
      tester,
      UndebitedExpensesBanner(
        service: service,
        currencyCode: 'EUR',
        localeName: 'fr',
        amountDecimalPlaces: 2,
      ),
    );
    await tester.tap(find.text('Gérer les dépenses'));
    await tester.pumpAndSettle();

    // Even whole amounts are shown with the configured decimals.
    expect(find.textContaining('850,00'), findsWidgets);

    service.dispose();
    expenses.dispose();
  });

  testWidgets('action buttons stack one per line with the icon before the label', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
      ];
    final service = await readyService(expenses);

    await pumpApp(
      tester,
      UndebitedExpensesBanner(
        service: service,
        currencyCode: 'EUR',
        localeName: 'fr',
      ),
      size: const Size(400, 900),
    );
    await tester.tap(find.text('Gérer les dépenses'));
    await tester.pumpAndSettle();

    // Carry to the current period is a "send forward" icon.
    expect(find.byIcon(Icons.schedule_send_rounded), findsOneWidget);
    // Debit on the origin period is a check sitting on the past clock.
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    // Debit on the current period reuses the mark-as-debited check icon.
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    // The leading icon sits before its label on the same line.
    final carryIconX = tester.getTopLeft(find.byIcon(Icons.schedule_send_rounded)).dx;
    final carryLabelX = tester.getTopLeft(find.text('Reporter vers Septembre 2026')).dx;
    expect(carryIconX, lessThan(carryLabelX));
    expect(
      tester.getCenter(find.byIcon(Icons.schedule_send_rounded)).dy,
      tester.getCenter(find.text('Reporter vers Septembre 2026')).dy,
    );

    // Each action is its own full-width button, stacked vertically.
    final carryY = tester.getTopLeft(find.text('Reporter vers Septembre 2026')).dy;
    final originY = tester.getTopLeft(find.text('Débiter sur Août 2026')).dy;
    final currentY = tester.getTopLeft(find.text('Débiter en Septembre 2026')).dy;
    expect(carryY, lessThan(originY));
    expect(originY, lessThan(currentY));

    service.dispose();
    expenses.dispose();
  });
}