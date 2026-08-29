import 'dart:async';

import 'package:flutter/material.dart';

mixin PulseHintAnimationMixin<T extends StatefulWidget> on TickerProviderStateMixin<T> {
  static const Duration hintFirstDelay = Duration(milliseconds: 1500);
  static const Duration hintRepeatInterval = Duration(seconds: 3);

  AnimationController? pulseController;
  Animation<double>? pulseAnimation;

  AnimationController? hintController;
  Animation<double>? hintAnimation;
  Timer? hintTimer;

  bool get withPulse;
  bool get withHint;
  bool get hintEnabled;

  void initPulseHintAnimations() {
    if (withPulse) {
      pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
      pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: pulseController!, curve: Curves.easeInOut),
      );
    }

    if (withHint && hintEnabled) {
      hintController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      hintAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: hintController!, curve: Curves.easeInOut),
      );
      scheduleHint();
    }
  }

  void scheduleHint() {
    _scheduleHint(hintFirstDelay);
  }

  void _scheduleHint(Duration delay) {
    hintTimer?.cancel();
    hintTimer = Timer(delay, () {
      if (!mounted || !hintEnabled || hintController == null) return;
      hintController!.forward(from: 0).then((_) {
        if (!mounted || !hintEnabled) return;
        _scheduleHint(hintRepeatInterval);
      });
    });
  }

  void cancelHint() {
    hintTimer?.cancel();
    hintController?.value = 0;
  }

  void onHintEnabled() {
    if (hintEnabled) scheduleHint();
  }

  void onHintDisabled() {
    cancelHint();
  }

  void disposePulseHintAnimations() {
    hintTimer?.cancel();
    hintController?.dispose();
    pulseController?.dispose();
  }

}

class PulseHint extends StatelessWidget {
  final Widget child;
  final Animation<double>? pulseAnimation;
  final Animation<double>? hintAnimation;

  const PulseHint({
    super.key,
    required this.child,
    this.pulseAnimation,
    this.hintAnimation,
  });

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    if (pulseAnimation != null) {
      result = ScaleTransition(scale: pulseAnimation!, child: result);
    }
    if (hintAnimation != null) {
      result = ScaleTransition(scale: hintAnimation!, child: result);
    }
    return result;
  }
}
