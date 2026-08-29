import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_expenses.dart';
import 'package:flutter/material.dart';

class CategoryExpenseList extends StatelessWidget {
  final List<CategoryExpenseSummary> summaries;
  final String currencyCode;
  final String localeName;
  final int decimalPlaces;
  final ValueChanged<CategoryExpenseSummary>? onTapCategory;

  const CategoryExpenseList({
    super.key,
    required this.summaries,
    required this.currencyCode,
    required this.localeName,
    this.decimalPlaces = 2,
    this.onTapCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: BudglySpacing.md,
      children: [
        for (final summary in summaries)
          CategoryExpenses(
            summary: summary,
            currencyCode: currencyCode,
            localeName: localeName,
            decimalPlaces: decimalPlaces,
            onTap: onTapCategory == null
                ? null
                : () => onTapCategory!(summary),
          ),
      ],
    );
  }
}
