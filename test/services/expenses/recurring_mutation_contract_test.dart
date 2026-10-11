import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/calculators/recurring_expense_versioning.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';

void main() {
  const versioning = RecurringExpenseVersioning();

  test('editing a recurring expense at the first occurrence replaces the series from the first date', () {
    final original = Fixtures.expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      amount: 100,
      debitDate: DateTime(2026, 1, 15),
      recurrence: RecurrenceType.monthly,
      recurrenceAnchorDay: 15,
    );
    final updated = original.copyWith(amount: 125);

    final result = versioning.split(
      original: original,
      updated: updated,
      effectiveDate: DateTime(2026, 1, 15),
    );

    expect(result.previous.id, 'e1');
    expect(result.next.id, 'e1');
    expect(result.next.amount, 125);
    expect(result.next.debitDate, DateTime(2026, 1, 15));
  });

  test('editing a recurring expense in the middle ends the old series the day before', () {
    final original = Fixtures.expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      amount: 100,
      debitDate: DateTime(2026, 1, 15),
      recurrence: RecurrenceType.monthly,
      recurrenceAnchorDay: 15,
      debitedOccurrences: const ['2026-01-15', '2026-02-15', '2026-03-15'],
    );
    final updated = original.copyWith(amount: 150);

    final result = versioning.split(
      original: original,
      updated: updated,
      effectiveDate: DateTime(2026, 3, 15),
    );

    expect(result.previous.endDate, DateTime(2026, 3, 14));
    expect(result.previous.debitedOccurrences, ['2026-01-15', '2026-02-15']);
    expect(result.next.debitDate, DateTime(2026, 3, 15));
    expect(result.next.amount, 150);
    expect(result.next.debitedOccurrences, ['2026-03-15']);
  });

  test('editing before the original occurrence is rejected', () {
    final original = Fixtures.expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      debitDate: DateTime(2026, 3, 15),
      recurrence: RecurrenceType.monthly,
    );

    expect(
      () => versioning.split(
        original: original,
        updated: original.copyWith(amount: 200),
        effectiveDate: DateTime(2026, 2, 15),
      ),
      throwsArgumentError,
    );
  });
}
