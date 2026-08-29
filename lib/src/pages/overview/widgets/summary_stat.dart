import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/pages/overview/widgets/summary_stat_value.dart';
import 'package:flutter/material.dart';

class SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  final String? detail;

  final Color? detailColor;
  final Color? color;
  final bool isEmphasized;

  final bool compact;

  final String? tooltip;

  final VoidCallback? onTap;

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
    final circleSize = compact ? 28.0 : 32.0;

    final showTrailing = !compact && onTap != null && trailingIcon != null;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: BudglySpacing.sm,
      children: [
        CircleAvatar(
          radius: circleSize / 2,
          backgroundColor: accent.withAlpha(28),
          child: Icon(icon, size: compact ? 14 : 16, color: accent),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: BudglySpacing.xs,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (compact
                        ? theme.textTheme.labelMedium
                        : theme.textTheme.labelSmall)
                    ?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: BudglySpacing.xs,
                children: [
                  Flexible(
                    child: SummaryStatValue(
                      value: value,
                      detail: detail,
                      compact: compact,
                      isEmphasized: isEmphasized,
                      color: color,
                      theme: theme,
                      detailColor: detailColor,
                    ),
                  ),
                  if (showTrailing)
                    Icon(
                      trailingIcon,
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
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
}

