import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/calculators/recurring_expense_versioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const versioning = RecurringExpenseVersioning();

  Expense expense({
    String? id = 'series-1',
    double amount = 10,
    DateTime? debitDate,
    DateTime? endDate,
    RecurrenceType recurrence = RecurrenceType.monthly,
    List<String> debited = const [],
  }) => Expense(
    id: id,
    accountId: 'a1',
    categoryId: 'c1',
    name: 'Subscription',
    amount: amount,
    debitDate: debitDate ?? DateTime(2026, 1, 15),
    endDate: endDate,
    recurrence: recurrence,
    debitedOccurrences: debited,
  );

  group('RecurringExpenseVersioning edge cases', () {
    test('rejects a non-recurring original', () {
      expect(
        () => versioning.split(
          original: expense(recurrence: RecurrenceType.none),
          updated: expense(amount: 20),
          effectiveDate: DateTime(2026, 3, 15),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an unsaved original without an id', () {
      expect(
        () => versioning.split(
          original: expense(id: null),
          updated: expense(amount: 20),
          effectiveDate: DateTime(2026, 3, 15),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an effective date before the original calendar day', () {
      expect(
        () => versioning.split(
          original: expense(debitDate: DateTime(2026, 3, 15)),
          updated: expense(amount: 20),
          effectiveDate: DateTime(2026, 3, 14, 23, 59),
        ),
        throwsArgumentError,
      );
    });

    test('same-day edit keeps the original series id and recurrence anchor', () {
      final result = versioning.split(
        original: expense(),
        updated: expense(id: 'ignored', amount: 20),
        effectiveDate: DateTime(2026, 1, 15, 22),
      );

      expect(result.previous.id, 'series-1');
      expect(result.next.id, 'series-1');
      expect(result.next.amount, 20);
      expect(result.next.recurrenceAnchorDay, 15);
      expect(result.previous.endDate, isNull);
    });

    test('middle split keeps only earlier debited occurrences in previous version', () {
      final result = versioning.split(
        original: expense(
          debited: const ['2026-01-15', '2026-02-15', '2026-03-15', '2026-04-15'],
        ),
        updated: expense(amount: 20),
        effectiveDate: DateTime(2026, 3, 15),
      );

      expect(result.previous.endDate, DateTime(2026, 3, 14));
      expect(result.previous.debitedOccurrences, ['2026-01-15', '2026-02-15']);
      expect(result.next.debitedOccurrences, ['2026-03-15', '2026-04-15']);
    });

    test('switching to non-recurring clears future debited occurrence metadata', () {
      final result = versioning.split(
        original: expense(debited: const ['2026-01-15', '2026-02-15']),
        updated: expense(amount: 20, recurrence: RecurrenceType.none),
        effectiveDate: DateTime(2026, 3, 15),
      );

      expect(result.next.recurrence, RecurrenceType.none);
      expect(result.next.debitedOccurrences, isEmpty);
    });
  });
}
