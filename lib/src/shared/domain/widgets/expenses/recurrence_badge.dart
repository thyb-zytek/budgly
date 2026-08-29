import 'package:flutter/material.dart';

class RecurrenceBadge extends StatelessWidget {
  final String label;

  const RecurrenceBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Chip(
      avatar: Icon(
        Icons.repeat_rounded,
        size: 12,
        color: theme.colorScheme.primary,
      ),
      label: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
