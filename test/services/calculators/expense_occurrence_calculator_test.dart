import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense({required String id, required DateTime date, bool debited = false}) => Expense(
      id: id,
      accountId: 'a',
      categoryId: 'c',
      name: id,
      amount: 10,
      debitDate: date,
      isDebited: debited,
    );

void main() {
  const calculator = ExpenseOccurrenceCalculator();

  test('forPeriod projects one-off expenses and sorts pending before debited', () {
    const period = Period(year: 2026, month: 8);
    final expenses = [
      _expense(id: 'debited', date: DateTime(2026, 8, 20), debited: true),
      _expense(id: 'pending', date: DateTime(2026, 8, 5)),
    ];
    final result = calculator.forPeriod(expenses, period);
    expect(result.map((e) => e.id), ['pending', 'debited']);
  });

  test('between expands recurring expenses only inside requested range', () {
    final expense = Expense(
      id: 'weekly',
      accountId: 'a',
      categoryId: 'c',
      name: 'Weekly',
      amount: 10,
      debitDate: DateTime(2026, 8, 1),
      recurrence: RecurrenceType.weekly,
    );
    final result = calculator.between([expense], DateTime(2026, 8, 10), DateTime(2026, 8, 25, 23, 59));
    expect(result.map((e) => e.date.day), [15, 22]);
  });

  test('sort uses date for occurrences with equal debit status', () {
    const period = Period(year: 2026, month: 8);
    final result = calculator.forPeriod([
      _expense(id: 'late', date: DateTime(2026, 8, 20)),
      _expense(id: 'early', date: DateTime(2026, 8, 2)),
    ], period);
    expect(result.map((e) => e.id), ['early', 'late']);
  });
}
