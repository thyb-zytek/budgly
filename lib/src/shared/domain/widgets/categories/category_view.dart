import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/shared/ui/widgets/actions/edit_delete_actions.dart';
import 'package:flutter/material.dart';

class CategoryView extends ConsumerWidget {
  final Category category;
  final Color? color;
  final bool showThreshold;
  final String? currencyCode;
  final String? localeName;
  final int? decimalPlaces;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CategoryView({
    super.key,
    required this.category,
    this.onEdit,
    this.onDelete,
    this.color,
    this.showThreshold = true,
    this.currencyCode,
    this.localeName,
    this.decimalPlaces,
  });

  String _formatThreshold({
    required double threshold,
    required String currency,
    required String localeName,
    required int decimalPlaces,
  }) {
    return formatCurrency(
      amount: threshold,
      currencyCode: currency,
      localeName: localeName,
      decimalPlaces: decimalPlaces,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final threshold = category.monthlyThreshold;
    final needsProfileFormatting =
        showThreshold &&
        threshold != null &&
        (currencyCode == null || localeName == null || decimalPlaces == null);
    final profileFormatting = needsProfileFormatting
        ? ref.watch(
            profileSessionProvider.select(
              (profile) => (
                currency: profile.currency,
                localeName: profile.locale.languageCode,
                decimalPlaces: profile.amountDecimalPlaces,
              ),
            ),
          )
        : null;
    final currency =
        currencyCode ??
        profileFormatting?.currency ??
        AppConstants.defaultCurrency;
    final resolvedLocaleName =
        localeName ??
        profileFormatting?.localeName ??
        AppConstants.defaultLocale;
    final resolvedDecimalPlaces =
        decimalPlaces ?? profileFormatting?.decimalPlaces ?? 2;
    final thresholdLabel = threshold == null
        ? tr.thresholdNotSet
        : showThreshold
        ? _formatThreshold(
            threshold: threshold,
            currency: currency,
            localeName: resolvedLocaleName,
            decimalPlaces: resolvedDecimalPlaces,
          )
        : '';

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
