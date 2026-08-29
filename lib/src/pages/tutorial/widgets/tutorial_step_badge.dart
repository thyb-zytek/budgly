import 'package:flutter/material.dart';

class TutorialStepBadge extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double size;

  const TutorialStepBadge({
    super.key,
    required this.child,
    this.color,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [tint.withAlpha(46), tint.withAlpha(0)],
        ),
      ),
      child: Center(child: child),
    );
  }
}
