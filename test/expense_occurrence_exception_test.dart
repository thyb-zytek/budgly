import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/expense_occurrence_exception.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense recurring({
    List<ExpenseOccurrenceException> exceptions = const [],
  }) {
    return Expense(
      id: 'expense-1',
      accountId: 'account-1',
      categoryId: 'category-1',
      name: 'Rent',
      amount: 900,
      debitDate: DateTime(2026, 1, 15),
      recurrence: RecurrenceType.monthly,
      occurrenceExceptions: exceptions,
    );
  }

  test('single occurrence deletion leaves the series and history intact', () {
    final expense = recurring(
      exceptions: const [
        ExpenseOccurrenceException(
          key: 'expense-1@2026-02-15',
          deleted: true,
        ),
      ],
    );

    final feb = expandExpenseOccurrences(
      expense,
      const Period(year: 2026, month: 2),
    );
    final mar = expandExpenseOccurrences(
      expense,
      const Period(year: 2026, month: 3),
    );

    expect(feb, isEmpty);
    expect(mar, hasLength(1));
    expect(expense.debitDate, DateTime(2026, 1, 15));
  });

  test('single occurrence modification overrides only that occurrence', () {
    final expense = recurring(
      exceptions: const [
        ExpenseOccurrenceException(
          key: 'expense-1@2026-02-15',
          amount: 950,
          name: 'Rent corrected',
          categoryId: 'category-2',
        ),
      ],
    );

    final feb = expandExpenseOccurrences(
      expense,
      const Period(year: 2026, month: 2),
    );
    final mar = expandExpenseOccurrences(
      expense,
      const Period(year: 2026, month: 3),
    );

    expect(feb.single.amount, 950);
    expect(feb.single.name, 'Rent corrected');
    expect(feb.single.categoryId, 'category-2');
    expect(mar.single.amount, 900);
    expect(mar.single.name, 'Rent');
    expect(mar.single.categoryId, 'category-1');
    expect(feb.single.isException, isTrue);
  });

  test('a moved exception is projected into the destination period', () {
    final expense = recurring(
      exceptions: [
        ExpenseOccurrenceException(
          key: 'expense-1@2026-01-15',
          debitDate: DateTime(2026, 2, 2),
          isDebited: false,
        ),
      ],
    );

    final jan = expandExpenseOccurrences(
      expense,
      const Period(year: 2026, month: 1),
    );
    final feb = expandExpenseOccurrences(
      expense,
      const Period(year: 2026, month: 2),
    );

    expect(jan, isEmpty);
    final moved = feb.where((o) => o.sourceDate == DateTime(2026, 1, 15));
    expect(moved, hasLength(1));
    expect(moved.single.date, DateTime(2026, 2, 2));
    expect(moved.single.key, 'expense-1@2026-01-15');
  });

  test('exception survives JSON serialization', () {
    const exception = ExpenseOccurrenceException(
      key: 'expense-1@2026-02-15',
      amount: 950,
      name: 'Rent corrected',
      categoryId: 'category-2',
      deleted: false,
      isDebited: true,
    );

    final decoded = ExpenseOccurrenceException.fromJson(exception.toJson());
    expect(decoded.key, exception.key);
    expect(decoded.amount, 950);
    expect(decoded.name, 'Rent corrected');
    expect(decoded.categoryId, 'category-2');
    expect(decoded.isDebited, isTrue);
  });
}
