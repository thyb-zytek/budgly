import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isHighlighted;

  const StatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      labelPadding: EdgeInsets.only(right: BudglySpacing.xs),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      backgroundColor:
          isHighlighted ? color.withAlpha(28) : Colors.transparent,
      side: BorderSide.none,
      padding: EdgeInsets.symmetric(horizontal: BudglySpacing.xxs, vertical: 0),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
