import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/services/calculators/expense_summary_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = ExpenseSummaryCalculator();
  final category = Category(
    id: 'food',
    accountId: 'account',
    name: 'Food',
  );

  ExpenseOccurrence occurrence(double amount, bool debited) {
    final expense = Expense(
      id: amount.toString(),
      accountId: 'account',
      categoryId: 'food',
      name: 'Expense',
      amount: amount,
      debitDate: DateTime(2026, 8, 1),
      isDebited: debited,
    );
    return ExpenseOccurrence(
      expense: expense,
      date: expense.debitDate,
      isDebited: debited,
    );
  }

  test('summarizes debited and pending amounts', () {
    final result = calculator.summarize(
      category: category,
      occurrences: [
        occurrence(20, true),
        occurrence(30, false),
        occurrence(10, false),
      ],
    );

    expect(result.total, 60);
    expect(result.debited, 20);
    expect(result.undebited, 40);
    expect(result.undebitedCount, 2);
  });
}
