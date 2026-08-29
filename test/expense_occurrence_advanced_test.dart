import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense buildExpense({
    String id = 'exp-1',
    String accountId = 'account-1',
    String categoryId = 'cat-1',
    required DateTime debitDate,
    DateTime? endDate,
    RecurrenceType recurrence = RecurrenceType.none,
    int? recurrenceAnchorDay,
    bool isDebited = false,
    List<String> debitedOccurrences = const [],
    double amount = 10.0,
  }) {
    return Expense(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      name: 'Test',
      amount: amount,
      debitDate: debitDate,
      endDate: endDate,
      recurrence: recurrence,
      recurrenceAnchorDay: recurrenceAnchorDay,
      isDebited: isDebited,
      debitedOccurrences: debitedOccurrences,
    );
  }

  group('expandExpenseOccurrencesBetween edge cases', () {
    test('recurring expense with endDate stops expanding at endDate', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
        endDate: DateTime(2026, 3, 15),
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31),
      );

      expect(result, hasLength(3));
      expect(result.last.date, DateTime(2026, 3, 15));
    });

    test('recurring expense whose endDate is before from returns empty', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
        endDate: DateTime(2026, 2, 15),
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 3, 1),
        DateTime(2026, 12, 31),
      );

      expect(result, isEmpty);
    });

    test('one-off expense outside the range returns empty', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 1, 15),
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );

      expect(result, isEmpty);
    });

    test('one-off expense exactly on from boundary is included', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 3, 1),
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );

      expect(result, hasLength(1));
    });

    test('one-off expense exactly on to boundary is included', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 3, 31),
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );

      expect(result, hasLength(1));
    });

    test('weekly recurring generates correct number of occurrences in 2 weeks', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 3, 2),
        recurrence: RecurrenceType.weekly,
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 3, 2),
        DateTime(2026, 3, 15),
      );

      expect(result, hasLength(2));
      expect(result[0].date, DateTime(2026, 3, 2));
      expect(result[1].date, DateTime(2026, 3, 9));
    });

    test('daily recurring expands correctly', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 3, 1),
        recurrence: RecurrenceType.daily,
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 5),
      );

      expect(result, hasLength(5));
      expect(result.first.date, DateTime(2026, 3, 1));
      expect(result.last.date, DateTime(2026, 3, 5));
    });

    test('monthly with anchor day 31 clamps correctly in short months', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 1, 31),
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: 31,
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 1, 1),
        DateTime(2026, 5, 31),
      );

      expect(result, hasLength(5));
      expect(result[0].date, DateTime(2026, 1, 31));
      expect(result[1].date, DateTime(2026, 2, 28));
      expect(result[2].date, DateTime(2026, 3, 31));
      expect(result[3].date, DateTime(2026, 4, 30));
      expect(result[4].date, DateTime(2026, 5, 31));
    });

    test('occurrence isDebited resolves per date for recurring', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
        debitedOccurrences: ['2026-01-15', '2026-03-15'],
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 1, 1),
        DateTime(2026, 5, 31),
      );

      expect(result[0].isDebited, isTrue);
      expect(result[1].isDebited, isFalse);
      expect(result[2].isDebited, isTrue);
      expect(result[3].isDebited, isFalse);
      expect(result[4].isDebited, isFalse);
    });

    test('bimonthly recurring expands every 2 months', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.bimonthly,
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31),
      );

      expect(result, hasLength(6));
      expect(result[0].date, DateTime(2026, 1, 15));
      expect(result[1].date, DateTime(2026, 3, 15));
      expect(result[2].date, DateTime(2026, 5, 15));
    });

    test('yearly recurring expands once per year', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 6, 15),
        recurrence: RecurrenceType.yearly,
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 1, 1),
        DateTime(2030, 12, 31),
      );

      expect(result, hasLength(5));
      expect(result[0].date, DateTime(2026, 6, 15));
      expect(result[4].date, DateTime(2030, 6, 15));
    });

    test('trimonthly recurring expands every 3 months', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 1, 10),
        recurrence: RecurrenceType.trimonthly,
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31),
      );

      expect(result, hasLength(4));
      expect(result[0].date, DateTime(2026, 1, 10));
      expect(result[1].date, DateTime(2026, 4, 10));
      expect(result[2].date, DateTime(2026, 7, 10));
      expect(result[3].date, DateTime(2026, 10, 10));
    });

    test('occurrence key format is id@YYYY-MM-DD', () {
      final expense = buildExpense(
        id: 'test-42',
        debitDate: DateTime(2026, 3, 5),
      );

      final result = expandExpenseOccurrencesBetween(
        expense,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );

      expect(result.single.key, 'test-42@2026-03-05');
    });
  });

  group('ExpenseOccurrence properties', () {
    test('delegates to expense fields', () {
      final expense = buildExpense(
        id: 'exp-99',
        categoryId: 'cat-7',
        amount: 42.5,
        debitDate: DateTime(2026, 6, 1),
        recurrence: RecurrenceType.monthly,
      );
      final occ = ExpenseOccurrence(
        expense: expense,
        date: DateTime(2026, 7, 1),
        isDebited: true,
      );

      expect(occ.id, 'exp-99');
      expect(occ.categoryId, 'cat-7');
      expect(occ.amount, 42.5);
      expect(occ.name, 'Test');
      expect(occ.recurrence, RecurrenceType.monthly);
    });

    test('id returns empty string when expense has null id', () {
      final expenseNoId = Expense(
        accountId: 'account-1',
        categoryId: 'cat-1',
        name: 'Test',
        amount: 10.0,
        debitDate: DateTime(2026, 1, 1),
      );
      final occ = ExpenseOccurrence(
        expense: expenseNoId,
        date: DateTime(2026, 1, 1),
        isDebited: false,
      );

      expect(occ.id, '');
    });
  });
}
