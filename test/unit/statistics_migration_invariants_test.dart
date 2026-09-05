import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';

void main() {
  const calculator = ExpenseOccurrenceCalculator();
  const period = Period(year: 2026, month: 3);

  test('moving an expense between accounts preserves the total contribution exactly once', () {
    final oldExpense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 125,
      debitDate: DateTime(2026, 3, 10),
    );
    final newExpense = oldExpense.copyWith(accountId: 'a2');

    final oldContribution = calculator.forPeriod([oldExpense], period)
        .fold(0.0, (sum, occurrence) => sum + occurrence.amount);
    final newContribution = calculator.forPeriod([newExpense], period)
        .fold(0.0, (sum, occurrence) => sum + occurrence.amount);

    expect(oldContribution, 125);
    expect(newContribution, 125);
    expect(oldContribution, newContribution);
  });

  test('moving an expense between categories preserves the category contribution exactly once', () {
    final oldExpense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 80,
      debitDate: DateTime(2026, 3, 10),
    );
    final newExpense = oldExpense.copyWith(categoryId: 'c2');

    final before = calculator.forPeriod([oldExpense], period)
        .fold(0.0, (sum, occurrence) => sum + occurrence.amount);
    final after = calculator.forPeriod([newExpense], period)
        .fold(0.0, (sum, occurrence) => sum + occurrence.amount);

    expect(before, 80);
    expect(after, 80);

    // After the move the old category must contribute zero and the new one
    // must carry the expense exactly once.
    final combinedAfterMove = calculator.forPeriod([newExpense], period)
        .where((occurrence) => occurrence.expense.categoryId == 'c2')
        .fold(0.0, (sum, occurrence) => sum + occurrence.amount);
    expect(combinedAfterMove, 80);
  });

  test('moving an expense between account and category changes both dimensions without changing amount', () {
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 60,
      debitDate: DateTime(2026, 3, 10),
    );
    final moved = expense.copyWith(accountId: 'a2', categoryId: 'c2');

    final occurrence = calculator.forPeriod([moved], period).single;
    expect(occurrence.expense.accountId, 'a2');
    expect(occurrence.expense.categoryId, 'c2');
    expect(occurrence.amount, 60);
  });
}
