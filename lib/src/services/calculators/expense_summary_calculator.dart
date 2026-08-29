import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';

class ExpenseSummaryCalculator {
  const ExpenseSummaryCalculator();

  CategoryExpenseSummary summarize({
    required Category category,
    required List<ExpenseOccurrence> occurrences,
  }) {
    double total = 0;
    double debited = 0;
    double undebited = 0;
    int undebitedCount = 0;

    for (final occurrence in occurrences) {
      total += occurrence.amount;
      if (occurrence.isDebited) {
        debited += occurrence.amount;
      } else {
        undebited += occurrence.amount;
        undebitedCount++;
      }
    }

    return CategoryExpenseSummary(
      category: category,
      total: total,
      debited: debited,
      undebited: undebited,
      undebitedCount: undebitedCount,
    );
  }

  List<CategoryExpenseSummary> summarizeByCategory({
    required List<ExpenseOccurrence> occurrences,
    required Category? Function(String categoryId) resolveCategory,
  }) {
    final grouped = <String, List<ExpenseOccurrence>>{};
    for (final occurrence in occurrences) {
      grouped.putIfAbsent(occurrence.categoryId, () => []).add(occurrence);
    }

    final summaries = <CategoryExpenseSummary>[];
    for (final entry in grouped.entries) {
      final category = resolveCategory(entry.key);
      if (category == null) continue;
      summaries.add(
        summarize(category: category, occurrences: entry.value),
      );
    }

    summaries.sort((a, b) => b.total.compareTo(a.total));
    return summaries;
  }
}
