import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/calculators/recurring_expense_versioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const versioning = RecurringExpenseVersioning();

  Expense buildExpense() => Expense(
        id: 'expense-1',
        accountId: 'account-1',
        categoryId: 'category-1',
        name: 'Rent',
        amount: 900,
        debitDate: DateTime(2026, 1, 31),
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: 31,
        debitedOccurrences: const [
          '2026-01-31',
          '2026-02-28',
          '2026-03-31',
        ],
      );

  test('keeps historical occurrences on the previous version', () {
    final original = buildExpense();
    final result = versioning.split(
      original: original,
      updated: original.copyWith(amount: 1000),
      effectiveDate: DateTime(2026, 3, 31),
    );

    expect(result.previous.endDate, DateTime(2026, 3, 30));
    expect(result.previous.amount, 900);
    expect(result.previous.debitedOccurrences, ['2026-01-31', '2026-02-28']);
    expect(result.next.amount, 1000);
    expect(result.next.debitedOccurrences, ['2026-03-31']);
  });

  test('preserves the original monthly anchor after a split', () {
    final original = buildExpense();
    final result = versioning.split(
      original: original,
      updated: original.copyWith(amount: 1000),
      effectiveDate: DateTime(2026, 2, 28),
    );

    expect(result.next.debitDate, DateTime(2026, 2, 28));
    expect(result.next.recurrenceAnchorDay, 31);
  });

  test('updates the original document when editing its first occurrence', () {
    final original = buildExpense();
    final result = versioning.split(
      original: original,
      updated: original.copyWith(amount: 1000),
      effectiveDate: original.debitDate,
    );

    expect(result.next.id, 'expense-1');
    expect(result.next.amount, 1000);
    expect(result.previous.id, 'expense-1');
  });
}
