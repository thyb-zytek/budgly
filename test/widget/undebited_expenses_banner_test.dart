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

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async => accountExpenses;
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
    addTearDown(expenses.dispose);
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
  });

  testWidgets('banner is empty when there is nothing pending', (tester) async {
    final expenses = FakeWidgetExpensesService();
    addTearDown(expenses.dispose);
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
  });

  testWidgets('dismiss button hides the banner', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
      ];
    addTearDown(expenses.dispose);
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
  });

  testWidgets('the action opens the undebited expenses page', (tester) async {
    final expenses = FakeWidgetExpensesService()
      ..accountExpenses = [
        expense(id: 'e1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
      ];
    addTearDown(expenses.dispose);
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

    // The report page opens on top of the banner even though it no longer
    // receives the banner's per-account service: it is now self-contained and
    // aggregates every account itself.
    expect(find.text('Dépenses à traiter'), findsOneWidget);
    expect(find.text('0 dépense(s) en attente'), findsOneWidget);

    service.dispose();
  });
}