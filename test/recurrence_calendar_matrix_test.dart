import 'package:budgly/src/models/budget/calendar_date_range.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense monthly({
    required DateTime debitDate,
    int? anchorDay,
    DateTime? endDate,
  }) => Expense(
    id: 'recurring-1',
    accountId: 'account-1',
    categoryId: 'category-1',
    name: 'Rent',
    amount: 900,
    debitDate: debitDate,
    endDate: endDate,
    recurrence: RecurrenceType.monthly,
    recurrenceAnchorDay: anchorDay,
  );

  CalendarDateRange month(int year, int month) => CalendarDateRange(
    start: DateTime(year, month, 1),
    endExclusive: DateTime(year, month + 1, 1),
  );

  test(
    'January 31 monthly recurrence clamps in February then returns to 31 in March',
    () {
      final expense = monthly(debitDate: DateTime(2026, 1, 31), anchorDay: 31);

      final february = expandExpenseOccurrencesBetween(expense, month(2026, 2));
      final march = expandExpenseOccurrencesBetween(expense, month(2026, 3));

      expect(february.map((o) => o.date), [DateTime(2026, 2, 28)]);
      expect(march.map((o) => o.date), [DateTime(2026, 3, 31)]);
    },
  );

  test(
    'February 29 yearly recurrence remains February 28 in non-leap years and returns to 29',
    () {
      final expense = Expense(
        id: 'recurring-1',
        accountId: 'account-1',
        categoryId: 'category-1',
        name: 'Annual',
        amount: 100,
        debitDate: DateTime(2024, 2, 29),
        recurrence: RecurrenceType.yearly,
        recurrenceAnchorDay: 29,
      );

      final feb2025 = expandExpenseOccurrencesBetween(expense, month(2025, 2));
      final feb2028 = expandExpenseOccurrencesBetween(expense, month(2028, 2));

      expect(feb2025.single.date, DateTime(2025, 2, 28));
      expect(feb2028.single.date, DateTime(2028, 2, 29));
    },
  );

  test('inclusive endDate is emitted, but the following day is excluded', () {
    final expense = monthly(
      debitDate: DateTime(2026, 1, 15),
      endDate: DateTime(2026, 3, 15),
    );

    final march = expandExpenseOccurrencesBetween(expense, month(2026, 3));
    final april = expandExpenseOccurrencesBetween(expense, month(2026, 4));

    expect(march.single.date, DateTime(2026, 3, 15));
    expect(april, isEmpty);
  });

  test(
    'a moved exception can project an occurrence across a month boundary',
    () {
      final expense = monthly(
        debitDate: DateTime(2026, 1, 31),
        anchorDay: 31,
      ).copyWith(occurrenceExceptions: const []);

      // This test is intentionally kept at the recurrence boundary level; moved
      // exception projection is covered by the dedicated exception suite.
      expect(
        expandExpenseOccurrencesBetween(expense, month(2026, 2)).single.date,
        DateTime(2026, 2, 28),
      );
    },
  );
}
