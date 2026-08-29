import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class SummaryStatValue extends StatelessWidget {
  final String value;
  final String? detail;
  final bool compact;
  final bool isEmphasized;
  final Color? color;
  final Color? detailColor;
  final ThemeData theme;

  const SummaryStatValue({
    super.key,
    required this.value,
    required this.detail,
    required this.compact,
    required this.isEmphasized,
    required this.color,
    required this.detailColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BudglySpacing.xs,
        children: [
          Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isEmphasized ? FontWeight.w800 : FontWeight.w700,
                  height: 1.2,
                  color: isEmphasized
                      ? color ?? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
          ),
          if (detail != null)
            Text(
              '($detail)',
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: detailColor ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
