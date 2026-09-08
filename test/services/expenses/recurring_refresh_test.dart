import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_expense_firestore.dart';
import '../../helpers/fake_stores.dart';

void main() {
  const march = Period(year: 2026, month: 3);

  late RefreshAwareExpenseFirestore firestore;
  late ExpensesService service;

  setUp(() {
    clearAllTestStores();
    firestore = RefreshAwareExpenseFirestore();
    service = ExpensesService(expenseFirestore: firestore);
    service.invalidateCache();
  });

  tearDown(() {
    service.dispose();
  });

  Expense monthly(String id, DateTime debitDate) => Expense(
        id: id,
        accountId: 'a1',
        categoryId: 'c1',
        name: 'Loyer',
        amount: 100,
        debitDate: debitDate,
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: debitDate.day,
      );

  test('creating a recurring expense refreshes an already-cached period',
      () async {
    firestore.serverExpenses.add(monthly('e1', DateTime(2026, 3, 5)));

    await service.listExpensesForPeriod('a1', march);
    const april = Period(year: 2026, month: 4);
    await service.listExpensesForPeriod('a1', april);
    expect(
      (await service.listExpensesForPeriod('a1', april)).map((e) => e.id),
      ['e1'],
    );

    await service.createExpense(
      Expense(
        id: 'e2',
        accountId: 'a1',
        categoryId: 'c2',
        name: 'Assurance',
        amount: 60,
        debitDate: DateTime(2026, 3, 10),
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: 10,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      (await service.listExpensesForPeriod('a1', april)).map((e) => e.id).toSet(),
      {'e1', 'e2'},
    );
  });

  test('period load populates the account store for later lookups', () async {
    firestore.serverExpenses.add(monthly('e1', DateTime(2026, 3, 5)));

    final loaded = await service.listExpensesForPeriod('a1', march);

    expect(loaded.map((e) => e.id), ['e1']);
    expect(service.getExpenseById('e1'), isNotNull);
    expect(service.getExpensesForAccount('a1'), hasLength(1));
  });

  test('single occurrence delete notifies and updates the store', () async {
    firestore.serverExpenses.add(monthly('e1', DateTime(2026, 3, 5)));
    await service.listExpensesForPeriod('a1', march);

    var notifications = 0;
    service.addListener(() => notifications++);

    final expense = service.getExpenseById('e1')!;
    await service.deleteSingleOccurrence(
      expense: expense,
      occurrenceDate: DateTime(2026, 3, 5),
    );

    expect(notifications, greaterThan(0));
    final stored = service.getExpenseById('e1');
    expect(stored, isNotNull);
    expect(stored!.occurrenceExceptions, hasLength(1));
    expect(stored.occurrenceExceptions.single.deleted, isTrue);
    final occurrences = const ExpenseOccurrenceCalculator()
        .between([stored], march.startOfMonth, march.endOfMonth);
    expect(occurrences, isEmpty);
  });

  test('future delete notifies and truncates the projected series', () async {
    firestore.serverExpenses.add(monthly('e1', DateTime(2026, 1, 5)));
    await service.listExpensesForPeriod('a1', march);

    var notifications = 0;
    service.addListener(() => notifications++);

    final expense = service.getExpenseById('e1')!;
    await service.deleteFutureOccurrences(
      expense: expense,
      occurrenceDate: DateTime(2026, 3, 5),
    );

    expect(notifications, greaterThan(0));
    final marchOccurrences = const ExpenseOccurrenceCalculator().between(
      [service.getExpenseById('e1')!],
      march.startOfMonth,
      march.endOfMonth,
    );
    expect(marchOccurrences, isEmpty);
    final februaryOccurrences = const ExpenseOccurrenceCalculator().between(
      [service.getExpenseById('e1')!],
      DateTime(2026, 2, 1),
      DateTime(2026, 2, 28),
    );
    expect(februaryOccurrences, hasLength(1));
  });

  test('single occurrence modify notifies and projection reflects the amount',
      () async {
    firestore.serverExpenses.add(monthly('e1', DateTime(2026, 3, 5)));
    await service.listExpensesForPeriod('a1', march);

    var notifications = 0;
    service.addListener(() => notifications++);

    final expense = service.getExpenseById('e1')!;
    final updated = await service.modifySingleOccurrence(
      original: expense,
      occurrenceDate: DateTime(2026, 3, 5),
      override: expense.copyWith(amount: 250),
    );

    expect(notifications, greaterThan(0));
    expect(updated.occurrenceExceptions, hasLength(1));
    expect(updated.occurrenceExceptions.single.amount, 250);
    final occurrence = const ExpenseOccurrenceCalculator()
        .between(
          [service.getExpenseById('e1')!],
          march.startOfMonth,
          march.endOfMonth,
        )
        .single;
    expect(occurrence.amount, 250);
  });

  test('delete of a loaded expense notifies listeners', () async {
    firestore.serverExpenses.add(
      Expense(
        id: 'e2',
        accountId: 'a1',
        categoryId: 'c1',
        name: 'Café',
        amount: 4.5,
        debitDate: DateTime(2026, 3, 10),
      ),
    );
    await service.listExpensesForPeriod('a1', march);

    var notifications = 0;
    service.addListener(() => notifications++);

    final result = await service.deleteExpense('e2', 'a1');

    expect(result, isTrue);
    expect(notifications, greaterThan(0));
    expect(service.getExpenseById('e2'), isNull);
  });
}