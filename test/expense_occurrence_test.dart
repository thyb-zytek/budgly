import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense buildExpense({
    String id = 'expense-1',
    DateTime? debitDate,
    RecurrenceType recurrence = RecurrenceType.none,
    bool isDebited = false,
    List<String> debitedOccurrences = const [],
  }) {
    return Expense(
      id: id,
      accountId: 'account-1',
      categoryId: 'category-1',
      name: 'Netflix',
      amount: 15.99,
      debitDate: debitDate ?? DateTime(2026, 1, 15),
      recurrence: recurrence,
      isDebited: isDebited,
      debitedOccurrences: debitedOccurrences,
    );
  }

  group('RecurrenceType date math', () {
    test('monthly clamps the day so Jan 31 never rolls into March', () {
      final jan31 = DateTime(2026, 1, 31);

      final feb = RecurrenceType.monthly.nextOccurrenceAfter(jan31);
      expect(feb, DateTime(2026, 2, 28));

      // Sticky clamping: keeping the anchor day restores the 31st in March.
      final mar = RecurrenceType.monthly.nextOccurrenceAfter(
        feb,
        anchorDay: jan31.day,
      );
      expect(mar, DateTime(2026, 3, 31));
    });

    test('previous occurrence walks back with the same clamping', () {
      final mar31 = DateTime(2026, 3, 31);

      final feb = RecurrenceType.monthly.previousOccurrenceBefore(mar31);
      expect(feb, DateTime(2026, 2, 28));

      final jan = RecurrenceType.monthly.previousOccurrenceBefore(
        feb,
        anchorDay: mar31.day,
      );
      expect(jan, DateTime(2026, 1, 31));
    });

    test('day based recurrences add calendar days', () {
      expect(
        RecurrenceType.daily.nextOccurrenceAfter(DateTime(2026, 2, 28)),
        DateTime(2026, 3, 1),
      );
      expect(
        RecurrenceType.weekly.nextOccurrenceAfter(DateTime(2026, 1, 1)),
        DateTime(2026, 1, 8),
      );
    });

    test('firstOccurrenceOnOrAfter jumps directly into the target window', () {
      final anchor = DateTime(2026, 1, 31);

      final result = RecurrenceType.monthly.firstOccurrenceOnOrAfter(
        anchor,
        DateTime(2027, 6, 1),
      );

      expect(result, DateTime(2027, 6, 30));
    });
  });

  group('expandExpenseOccurrences', () {
    test('one-off expense appears only in its debit date period', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 3, 12),
      );

      final inMarch = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 3),
      );
      expect(inMarch, hasLength(1));
      expect(inMarch.single.date, DateTime(2026, 3, 12));

      final inApril = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 4),
      );
      expect(inApril, isEmpty);
    });

    test('monthly recurring expense is propagated to every period', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 1, 31),
        recurrence: RecurrenceType.monthly,
      );

      final feb = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 2),
      );
      expect(feb.single.date, DateTime(2026, 2, 28));

      final mar = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 3),
      );
      expect(mar.single.date, DateTime(2026, 3, 31));

      // Does not appear before its anchor date.
      final before = expandExpenseOccurrences(
        expense,
        const Period(year: 2025, month: 12),
      );
      expect(before, isEmpty);
    });

    test('weekly recurring expense generates multiple occurrences in a month',
        () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 2, 2),
        recurrence: RecurrenceType.weekly,
      );

      final occurrences = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 2),
      );

      expect(occurrences, hasLength(4));
      expect(occurrences.first.date, DateTime(2026, 2, 2));
      expect(occurrences.last.date, DateTime(2026, 2, 23));
    });

    test('occurrence debited state is resolved per date', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
        debitedOccurrences: const ['2026-01-15', '2026-03-15'],
      );

      final jan = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 1),
      );
      expect(jan.single.isDebited, isTrue);

      final feb = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 2),
      );
      expect(feb.single.isDebited, isFalse);

      final mar = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 3),
      );
      expect(mar.single.isDebited, isTrue);
    });

    test('occurrence key is stable and unique per expense and date', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
      );

      final jan = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 1),
      ).single;
      final feb = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 2),
      ).single;

      expect(jan.key, 'expense-1@2026-01-15');
      expect(feb.key, 'expense-1@2026-02-15');
      expect(jan.key, isNot(feb.key));
    });
  });
}
