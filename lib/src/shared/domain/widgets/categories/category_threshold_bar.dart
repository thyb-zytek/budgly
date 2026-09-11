import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/services/calculators/category_threshold_calculator.dart';
import 'package:flutter/material.dart';

class CategoryThresholdBar extends StatelessWidget {
  final CategoryThresholdProgress progress;
  final String currencyCode;
  final String localeName;
  final int decimalPlaces;
  const CategoryThresholdBar({
    super.key,
    required this.progress,
    required this.currencyCode,
    required this.localeName,
    this.decimalPlaces = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (!progress.isEnabled) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context)!;
    final color = switch (progress.state) {
      // Blend toward the error color rather than overriding a single RGB
      // channel (the previous `scheme.error.withValues(green: 0.5)` just
      // clobbered the green channel of an already red-dominant color,
      // producing an unpredictable muddy tone instead of a distinct
      // warning color).
      CategoryThresholdState.warning =>
        Color.lerp(scheme.tertiary, scheme.error, 0.6)!,
      CategoryThresholdState.exceeded => scheme.error,
      _ => scheme.tertiary,
    };
    final amount = formatCurrency(
      amount: progress.state == CategoryThresholdState.exceeded
          ? progress.overshoot
          : progress.remaining,
      currencyCode: currencyCode,
      localeName: localeName,
      decimalPlaces: decimalPlaces,
    );
    final label = progress.state == CategoryThresholdState.exceeded
        ? tr.thresholdExceeded(amount)
        : tr.thresholdProgressRemaining(amount);
    return Semantics(
      label: tr.monthlyThreshold,
      value: '${(progress.rawProgress * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BudglySpacing.sm,
        children: [
          Text(
            label,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          LinearProgressIndicator(
            value: progress.progress,
            minHeight: BudglySpacing.sm,
            borderRadius: BorderRadius.circular(99),
            color: color,
          ),
        ],
      ),
    );
  }
}
