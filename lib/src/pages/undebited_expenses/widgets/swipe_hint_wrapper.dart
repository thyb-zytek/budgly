import 'dart:async';

import 'package:budgly/src/pages/undebited_expenses/widgets/swipe_hint_content.dart';
import 'package:flutter/material.dart';

/// Wraps the first [UndebitedExpenseCard] of the list with a transient,
/// non-interactive animation that demonstrates both swipe directions
/// (report/debit-now on the right, debit-on-origin on the left) until the
/// user interacts with a card or a short number of repeats have played.
class UndebitedSwipeHintWrapper extends StatefulWidget {
  final Widget child;

  const UndebitedSwipeHintWrapper({super.key, required this.child});

  @override
  UndebitedSwipeHintWrapperState createState() =>
      UndebitedSwipeHintWrapperState();
}

class UndebitedSwipeHintWrapperState extends State<UndebitedSwipeHintWrapper>
    with SingleTickerProviderStateMixin {
  static const Duration _firstDelay = Duration(seconds: 3);
  static const Duration _repeatDelay = Duration(seconds: 7);

  late final AnimationController _controller;
  Timer? _timer;
  bool _stopped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _schedule(_firstDelay);
  }

  void _schedule(Duration delay) {
    _timer = Timer(delay, () {
      if (!mounted || _stopped) return;
      _controller.forward(from: 0);
      _schedule(_repeatDelay);
    });
  }

  void stop() {
    if (_stopped) return;
    _stopped = true;
    _timer?.cancel();
    _controller.value = 0;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_stopped)
          Positioned.fill(
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) =>
                    UndebitedSwipeHintContent(progress: _controller.value),
              ),
            ),
          ),
      ],
    );
  }
}
