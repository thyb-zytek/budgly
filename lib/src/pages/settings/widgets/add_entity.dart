import 'package:budgly/src/shared/ui/widgets/layout/budgly_fab.dart';
import 'package:flutter/material.dart';

class AddEntity extends StatelessWidget {
  final String heroTag;
  final bool disabled;
  final VoidCallback onPressed;
  final String? label;

  const AddEntity({
    super.key,
    required this.onPressed,
    required this.heroTag,
    this.disabled = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: BudglyFab(
        heroTag: heroTag,
        disabled: disabled,
        onPressed: onPressed,
        label: label,
      ),
    );
  }
}
