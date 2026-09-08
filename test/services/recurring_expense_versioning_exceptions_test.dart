import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence_exception.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/calculators/recurring_expense_versioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('split keeps exceptions on their historical side', () {
    final original = Expense(
      id: 'expense-1',
      accountId: 'account-1',
      categoryId: 'category-1',
      name: 'Rent',
      amount: 900,
      debitDate: DateTime(2026, 1, 15),
      recurrence: RecurrenceType.monthly,
      occurrenceExceptions: const [
        ExpenseOccurrenceException(key: 'expense-1@2026-02-15', amount: 950),
        ExpenseOccurrenceException(key: 'expense-1@2026-04-15', deleted: true),
      ],
    );

    final result = const RecurringExpenseVersioning().split(
      original: original,
      updated: original.copyWith(amount: 1000),
      effectiveDate: DateTime(2026, 3, 15),
    );

    expect(result.previous.occurrenceExceptions.map((e) => e.key), [
      'expense-1@2026-02-15',
    ]);
    expect(result.next.occurrenceExceptions.map((e) => e.key), [
      'expense-1@2026-04-15',
    ]);
  });
}
