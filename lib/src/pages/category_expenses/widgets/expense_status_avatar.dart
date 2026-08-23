import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:flutter/material.dart';

class ExpenseStatusAvatar extends StatelessWidget {
  final Color? color;
  final bool isDebited;

  const ExpenseStatusAvatar({super.key, this.color, required this.isDebited});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDebited = this.isDebited;
    final success = ButtonType.success.colors(theme);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDebited
            ? color?.withValues(alpha: 0.2) ?? success.background.withValues(alpha: 0.15)
            : theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isDebited ? Icons.check_rounded : Icons.schedule_rounded,
        size: 24,
        color: isDebited
            ? color ?? success.foreground
            : theme.colorScheme.primary,
      ),
    );
  }
}
