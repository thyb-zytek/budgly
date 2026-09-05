import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';

class OverviewMetricsCalculator {
  const OverviewMetricsCalculator();

  double totalExpenses(List<ExpenseOccurrence> occurrences) =>
      occurrences.fold(0.0, (sum, occurrence) => sum + occurrence.amount);

  double pendingExpenses(List<ExpenseOccurrence> occurrences) =>
      occurrences
          .where((occurrence) => !occurrence.isDebited)
          .fold(0.0, (sum, occurrence) => sum + occurrence.amount);

  int? remainingWeekends(Period period) {
    if (period.isBefore(Period.current())) return null;
    if (period == Period.current()) return period.remainingWeekends();
    return period.totalWeekends();
  }

  double? weeklyBudget({
    required double remaining,
    required int? remainingWeekends,
  }) {
    if (remainingWeekends == null) return null;
    return remaining / (remainingWeekends > 0 ? remainingWeekends : 1);
  }
}
