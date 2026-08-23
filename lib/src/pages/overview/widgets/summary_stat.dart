import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:flutter/material.dart';

/// A single stat rendered flat, sharing the exact same visual language
/// in both flavours — a tinted icon circle on the left, caption and bold
/// value on the right — only scaled down for the compact variant used in
/// the collapsed header bar. No background box anywhere: the stat sits
/// directly on its surface.
///
/// An optional [detail] (e.g. the pending amount for "Expenses") is
/// appended to the value between parentheses, colored with [detailColor]
/// so it stands out from the main figure while staying secondary.
///
/// Values are wrapped in a [FittedBox] (scale down) instead of being
/// ellipsized: amounts always stay fully readable whatever the screen
/// width, they just shrink gracefully on tight layouts.
class SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// Secondary figure shown between parentheses after [value]
  /// (e.g. upcoming debits inside the total expenses).
  final String? detail;

  /// Color of the parenthesized [detail]; defaults to a muted variant
  /// color. Set it to an accent (e.g. [ColorScheme.error] for pending
  /// amounts) when the detail should stand out.
  final Color? detailColor;
  final Color? color;
  final bool isEmphasized;

  /// Smaller metrics for the collapsed header bar.
  final bool compact;

  /// Shown on long-press/hover — used to explain when a value is an
  /// estimate rather than a value actually set for this period.
  final String? tooltip;

  /// Makes the whole stat tappable (e.g. tap "Revenue" to set it).
  final VoidCallback? onTap;

  /// Small icon appended after the value, e.g. a pencil to hint the
  /// stat is editable. Only shown in expanded flavour when [onTap] is
  /// also set.
  final IconData? trailingIcon;

  const SummaryStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.detailColor,
    this.color,
    this.isEmphasized = false,
    this.compact = false,
    this.tooltip,
    this.onTap,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final circleSize = compact ? 22.0 : 32.0;
    // The edit hint stays an expanded-only affordance; in the collapsed
    // bar tapping the stat already opens the editor.
    final showTrailing = !compact && onTap != null && trailingIcon != null;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: accent.withAlpha(28),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: compact ? 12 : 16, color: accent),
        ),
        SizedBox(width: compact ? 7 : 9),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: _valueRow(theme)),
                  if (showTrailing) ...[
                    const SizedBox(width: 3),
                    Icon(
                      trailingIcon,
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final tappable = onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: content,
          );

    return tooltip == null
        ? tappable
        : Tooltip(message: tooltip!, child: tappable);
  }

  /// The stat value with its optional parenthesized detail, scaled
  /// down to fit instead of clipped.
  Widget _valueRow(ThemeData theme) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            style:
                (compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      fontWeight: isEmphasized
                          ? FontWeight.w800
                          : FontWeight.w700,
                      height: 1.2,
                      color: isEmphasized
                          ? color ?? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 3),
            Text(
              '($detail)',
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: detailColor ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Immutable description of a single stat, independent of how it will be
/// laid out (expanded vs. collapsed header). Call [build] to turn it into
/// the actual [SummaryStat] widget once the target [compact]-ness is known.
class OverviewStatItem {
  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final Color? detailColor;
  final Color color;
  final bool isEmphasized;
  final String? tooltip;
  final VoidCallback? onTap;
  final IconData? trailingIcon;

  const OverviewStatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.detailColor,
    required this.color,
    this.isEmphasized = false,
    this.tooltip,
    this.onTap,
    this.trailingIcon,
  });

  SummaryStat build({bool compact = false}) => SummaryStat(
    icon: icon,
    label: label,
    value: value,
    detail: detail,
    detailColor: detailColor,
    color: color,
    isEmphasized: isEmphasized,
    compact: compact,
    tooltip: tooltip,
    onTap: onTap,
    trailingIcon: trailingIcon,
  );
}

/// The full set of period stats, computed once from the view model's
/// current state and shared by the expanded summary card and the
/// collapsed bar — so the value/color/tooltip logic for each stat
/// (what "Revenue" shows when unset, when a stat counts as over-budget,
/// etc.) lives in exactly one place instead of being duplicated across
/// both layouts, which is how they'd previously drifted out of sync
/// (e.g. only one of the two showing the "remaining" tooltip).
///
/// Upcoming (not yet debited) expenses are folded into the "Expenses"
/// stat as a parenthesized detail rather than exposed as a separate
/// stat — it saves space and reads naturally: "Expenses 56 € (12 €)".
class OverviewSummaryStats {
  final OverviewStatItem revenue;
  final OverviewStatItem expenses;
  final OverviewStatItem remaining;
  final OverviewStatItem? weekly;

  const OverviewSummaryStats({
    required this.revenue,
    required this.expenses,
    required this.remaining,
    this.weekly,
  });

  factory OverviewSummaryStats.from(
    BuildContext context,
    OverviewViewModel viewModel,
    String Function(double) formatAmount, {
    VoidCallback? onEditRevenue,
  }) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final hasRevenue = viewModel.hasRevenue;
    final isEstimated = viewModel.isRevenueEstimated;
    final isOverBudget = viewModel.remaining < 0;

    return OverviewSummaryStats(
      revenue: OverviewStatItem(
        icon: Icons.account_balance_wallet_rounded,
        label: tr.revenue,
        value: hasRevenue
            ? formatAmount(viewModel.revenue)
            : isEstimated
            ? '≈ ${formatAmount(viewModel.effectiveRevenue)}'
            : '—',
        color: theme.colorScheme.secondary,
        tooltip: isEstimated ? tr.revenueEstimatedHint : null,
        onTap: onEditRevenue,
        trailingIcon: hasRevenue ? Icons.edit_rounded : Icons.add_rounded,
      ),
      expenses: OverviewStatItem(
        icon: Icons.trending_down_rounded,
        label: tr.expenses,
        value: formatAmount(viewModel.totalExpenses),
        color: theme.colorScheme.tertiary,
      ),
      remaining: OverviewStatItem(
        icon: Icons.savings_rounded,
        label: tr.remaining,
        value: formatAmount(viewModel.remaining),
        color: isOverBudget
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
        isEmphasized: true,
        tooltip: hasRevenue
            ? tr.remainingBasedOnRevenueHint
            : isEstimated
            ? tr.revenueEstimatedHint
            : null,
      ),
      weekly: viewModel.weeklyBudget != null
          ? OverviewStatItem(
              icon: Icons.calendar_view_week_rounded,
              label: tr.remainingWeekend,
              value: formatAmount(viewModel.weeklyBudget!),
              color: theme.colorScheme.primary,
            )
          : null,
    );
  }
}
