import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';

/// Builds the occurrences visible for a period and applies the common UI sort.
/// Keeping this projection in one place prevents the Overview and category
/// detail screens from implementing subtly different occurrence ordering.
class ExpenseOccurrenceCalculator {
  const ExpenseOccurrenceCalculator();

  List<ExpenseOccurrence> forPeriod(
    Iterable<Expense> expenses,
    Period period,
  ) {
    final result = <ExpenseOccurrence>[];
    for (final expense in expenses) {
      result.addAll(expandExpenseOccurrences(expense, period));
    }
    _sort(result);
    return result;
  }

  List<ExpenseOccurrence> between(
    Iterable<Expense> expenses,
    DateTime start,
    DateTime end,
  ) {
    final result = <ExpenseOccurrence>[];
    for (final expense in expenses) {
      result.addAll(expandExpenseOccurrencesBetween(expense, start, end));
    }
    _sort(result);
    return result;
  }

  static void _sort(List<ExpenseOccurrence> occurrences) {
    occurrences.sort((a, b) {
      if (a.isDebited != b.isDebited) return a.isDebited ? 1 : -1;
      return a.date.compareTo(b.date);
    });
  }
}
