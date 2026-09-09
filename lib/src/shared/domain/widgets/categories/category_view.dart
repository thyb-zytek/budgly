import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/shared/ui/widgets/actions/edit_delete_actions.dart';
import 'package:flutter/material.dart';

class CategoryView extends StatelessWidget {
  final Category category;
  final Color? color;
  final bool showThreshold;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CategoryView({
    super.key,
    required this.category,
    this.onEdit,
    this.onDelete,
    this.color,
    this.showThreshold = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final profile = ProfileStore.instance;
    final threshold = category.monthlyThreshold;
    final thresholdLabel = threshold == null
        ? tr.thresholdNotSet
        : formatCurrency(
            amount: threshold,
            currencyCode: profile.currency,
            localeName: profile.locale.toLanguageTag(),
            decimalPlaces: profile.amountDecimalPlaces,
          );

    return Row(
      spacing: 16,
      children: [
        if (category.icon != null)
          CategoryIconView(
            icon: category.icon!,
            color: category.color ?? Colors.grey,
          )
        else
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: category.color ?? Colors.grey,
            ),
            child: Icon(
              Icons.category,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 48 * 0.6,
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: BudglySpacing.xs,
            children: [
              Text(
                category.name ?? '',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showThreshold)
                Text(
                  threshold == null
                      ? tr.thresholdNotSet
                      : '${tr.threshold}: $thresholdLabel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (onEdit != null || onDelete != null)
          EditDeleteActions(onEdit: onEdit, onDelete: onDelete),
      ],
    );
  }
}
