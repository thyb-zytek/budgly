import 'package:flutter/material.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';

class RecurrenceBadge extends StatelessWidget {
  final String label;

  const RecurrenceBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsetsGeometry.directional(end: BudglySpacing.xs),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: BudglySpacing.sm,
          vertical: BudglySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 2,
          children: [
            Icon(
              Icons.repeat_rounded,
              size: BudglySpacing.md,
              color: theme.colorScheme.primary,
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
