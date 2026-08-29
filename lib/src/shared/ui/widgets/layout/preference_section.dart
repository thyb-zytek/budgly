import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class PreferenceSection extends StatelessWidget {
  final String title;
  final Widget child;

  const PreferenceSection({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(BudglySpacing.lg, BudglySpacing.sm, BudglySpacing.sm, BudglySpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall!.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: child,
          ),
        ],
      ),
    );
  }
}
