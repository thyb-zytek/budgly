import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense buildExpense({
    double amount = 15,
    DateTime? debitDate,
    RecurrenceType recurrence = RecurrenceType.monthly,
    bool isDebited = false,
    List<String> debitedOccurrences = const [],
    Map<String, double> amountOverrides = const {},
    Map<String, double> amountHistory = const {},
  }) {
    return Expense(
      id: 'expense-1',
      accountId: 'account-1',
      categoryId: 'category-1',
      name: 'Rent',
      amount: amount,
      debitDate: debitDate ?? DateTime(2026, 1, 15),
      recurrence: recurrence,
      isDebited: isDebited,
      debitedOccurrences: debitedOccurrences,
      amountOverrides: amountOverrides,
      amountHistory: amountHistory,
    );
  }

  group('amountAt', () {
    test('returns the template amount without overrides or history', () {
      final expense = buildExpense(amount: 15);

      expect(expense.amountAt(DateTime(2026, 3, 15)), 15);
    });

    test('prefers a one-off override over everything else', () {
      final expense = buildExpense(
        amount: 15,
        amountOverrides: const {'2026-03-15': 18},
      );

      expect(expense.amountAt(DateTime(2026, 3, 15)), 18);
      expect(expense.amountAt(DateTime(2026, 4, 15)), 15);
    });

    test('resolves the latest effective-date entry on or before the date', () {
      final expense = buildExpense(
        amount: 20,
        debitDate: DateTime(2026, 1, 15),
        amountHistory: const {
          '2026-01-15': 15,
          '2026-04-15': 22,
        },
      );

      expect(expense.amountAt(DateTime(2026, 2, 15)), 15);
      expect(expense.amountAt(DateTime(2026, 4, 15)), 22);
      expect(expense.amountAt(DateTime(2026, 5, 15)), 22);
    });
  });

  group('withRecurringAmountChange', () {
    test('past occurrence writes an override and keeps others stable', () {
      final expense = buildExpense(amount: 15);
      final past = DateTime.now().subtract(const Duration(days: 90));

      final updated = expense.withRecurringAmountChange(past, 18);

      expect(updated.amount, 15);
      expect(updated.amountHistory, isEmpty);
      expect(updated.amountOverrides[Expense.isoDate(past)], 18);
      expect(updated.amountAt(past.add(const Duration(days: 31))), 15);
    });

    test('debited occurrence writes an override even when not past', () {
      final occurrence = DateTime.now().add(const Duration(days: 30));
      final expense = buildExpense(
        amount: 15,
        debitedOccurrences: [Expense.isoDate(occurrence)],
      );

      final updated = expense.withRecurringAmountChange(occurrence, 18);

      expect(updated.amount, 15);
      expect(updated.amountOverrides[Expense.isoDate(occurrence)], 18);
    });

    test(
      'current/future occurrence updates the template from that date onward',
      () {
        final expense = buildExpense(amount: 15);
        final future = DateTime.now().add(const Duration(days: 60));

        final updated = expense.withRecurringAmountChange(future, 18);

        expect(updated.amount, 18);
        expect(updated.amountOverrides, isEmpty);
        expect(updated.amountAt(future), 18);
        expect(
          updated.amountAt(future.subtract(const Duration(days: 1))),
          15,
        );
      },
    );

    test('seeds history from the debit date on the first forward change', () {
      final expense = buildExpense(amount: 15);
      final occurrence = DateTime.now().add(const Duration(days: 60));
      final earlier = occurrence.subtract(const Duration(days: 31));

      final updated = expense.withRecurringAmountChange(occurrence, 18);

      expect(updated.amountHistory['2026-01-15'], 15);
      expect(updated.amountHistory[Expense.isoDate(occurrence)], 18);
      expect(updated.amountAt(earlier), 15);
      expect(updated.amountAt(occurrence), 18);
    });

    test('editing an overridden occurrence updates only that override', () {
      final expense = buildExpense(
        amount: 15,
        amountOverrides: const {'2026-03-15': 12},
      );

      final updated = expense.withRecurringAmountChange(
        DateTime(2026, 3, 15),
        14,
      );

      expect(updated.amount, 15);
      expect(updated.amountHistory, isEmpty);
      expect(updated.amountOverrides['2026-03-15'], 14);
    });

    test('non-recurring expense simply changes its amount', () {
      final expense = buildExpense(
        amount: 15,
        recurrence: RecurrenceType.none,
      );

      final updated = expense.withRecurringAmountChange(
        DateTime(2026, 3, 15),
        18,
      );

      expect(updated.amount, 18);
      expect(updated.amountOverrides, isEmpty);
      expect(updated.amountHistory, isEmpty);
    });

    test('same amount returns the expense unchanged', () {
      final expense = buildExpense(amount: 15);

      final updated = expense.withRecurringAmountChange(
        DateTime(2026, 9, 15),
        15,
      );

      expect(updated, same(expense));
    });
  });

  group('occurrence amount resolution', () {
    test('occurrences expose the resolved amount for their date', () {
      final expense = buildExpense(
        amount: 15,
        amountOverrides: const {'2026-03-15': 18},
      );

      final march = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 3),
      ).single;
      final april = expandExpenseOccurrences(
        expense,
        const Period(year: 2026, month: 4),
      ).single;

      expect(march.amount, 18);
      expect(april.amount, 15);
    });
  });
}
