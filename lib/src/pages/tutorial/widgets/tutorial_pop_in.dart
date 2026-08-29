import 'package:flutter/material.dart';

class TutorialPopIn extends StatelessWidget {
  final Widget child;

  const TutorialPopIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(scale: t, child: child),
        );
      },
      child: child,
    );
  }
}
