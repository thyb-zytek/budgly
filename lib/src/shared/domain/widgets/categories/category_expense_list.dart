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
      children: [
        for (var i = 0; i < summaries.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          CategoryExpenses(
            summary: summaries[i],
            currencyCode: currencyCode,
            localeName: localeName,
            decimalPlaces: decimalPlaces,
            onTap: onTapCategory == null
                ? null
                : () => onTapCategory!(summaries[i]),
          ),
        ],
      ],
    );
  }
}
