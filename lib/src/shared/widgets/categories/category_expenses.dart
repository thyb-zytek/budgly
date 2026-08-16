import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/shared/widgets/categories/category_details.dart';
import 'package:budgly/src/shared/widgets/categories/category_view.dart';
import 'package:flutter/material.dart';

/// One category row in the expense list: icon, name, total, and the
/// debited/pending split as status chips. This replaces the previous
/// two side-by-side detail blocks, which took twice the vertical
/// space to convey the same information.
class CategoryExpenses extends StatelessWidget {
  final CategoryExpenseSummary summary;
  final String currencyCode;
  final String localeName;
  final VoidCallback? onTap;

  const CategoryExpenses({
    super.key,
    required this.summary,
    required this.currencyCode,
    required this.localeName,
    this.onTap,
  });

  String _format(double value) {
    return formatCurrency(
      amount: value,
      currencyCode: currencyCode,
      localeName: localeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final category = summary.category;
    final hasPending = summary.undebitedCount > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(70),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(child: CategoryView(category: category)),
                Text(
                  _format(summary.total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatusChip(
                  label: tr.debited(_format(summary.debited)),
                  icon: Icons.check_circle_outline_rounded,
                  color: theme.colorScheme.tertiary,
                ),
                if (hasPending)
                  StatusChip(
                    label: tr.pending(
                      summary.undebitedCount,
                      _format(summary.undebited),
                    ),
                    icon: Icons.schedule_rounded,
                    color: theme.colorScheme.error,
                    isHighlighted: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}