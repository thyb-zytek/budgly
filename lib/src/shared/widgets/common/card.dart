import 'package:flutter/material.dart';

class BudglyCard extends StatelessWidget {
  final Color? background;
  final Widget child;

  const BudglyCard({super.key, this.background, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: background ?? Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ).copyWith(right: 8),
        child: child,
      ),
    );
  }
}
