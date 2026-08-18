import 'dart:async';

import 'package:flutter/material.dart';

mixin PulseHintAnimationMixin<T extends StatefulWidget> on TickerProviderStateMixin<T> {
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
    hintTimer?.cancel();
    hintTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || !hintEnabled) return;
      hintController!.forward(from: 0).then((_) => scheduleHint());
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

  Widget wrapWithPulseHint(Widget child) {
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
