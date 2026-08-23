import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter/material.dart';

class PeriodSlideSwitcher extends StatelessWidget {
  final Period period;
  final int direction;
  final Widget child;

  const PeriodSlideSwitcher({
    super.key,
    required this.period,
    required this.direction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final isIncoming = child.key == ValueKey(period);
        final dir = direction >= 0 ? 1.0 : -1.0;
        final begin = Offset(isIncoming ? dir : -dir * 0.25, 0);
        return SlideTransition(
          position: Tween(begin: begin, end: Offset.zero).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(period), child: child),
    );
  }
}
