import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/calculators/overview_metrics_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = OverviewMetricsCalculator();

  test('computes total and pending expenses', () {
    final occurrences = [
      _occurrence(10, true),
      _occurrence(7.5, false),
    ];
    expect(calculator.totalExpenses(occurrences), 17.5);
    expect(calculator.pendingExpenses(occurrences), 7.5);
  });

  test('returns no remaining weekends for past periods', () {
    final period = Period.current().addMonths(-1);
    expect(calculator.remainingWeekends(period), isNull);
  });

  test('weekly budget divides by remaining weekends and avoids zero division', () {
    expect(
      calculator.weeklyBudget(remaining: 120, remainingWeekends: 4),
      30,
    );
    expect(
      calculator.weeklyBudget(remaining: 120, remainingWeekends: 0),
      120,
    );
    expect(
      calculator.weeklyBudget(remaining: 120, remainingWeekends: null),
      isNull,
    );
  });
}

ExpenseOccurrence _occurrence(double amount, bool debited) => ExpenseOccurrence(
      expense: Expense(accountId: 'a', categoryId: 'c', name: 'test', amount: amount, debitDate: DateTime(2026, 1, 1)),
      date: DateTime(2026, 1, 1),
      isDebited: debited,
    );
