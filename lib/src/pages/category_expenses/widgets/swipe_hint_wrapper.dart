import 'dart:async';

import 'package:budgly/src/pages/category_expenses/widgets/swipe_hint_content.dart';
import 'package:flutter/material.dart';

class SwipeHintWrapper extends StatefulWidget {
  final Widget child;
  final bool isDebited;

  const SwipeHintWrapper({
    super.key,
    required this.child,
    required this.isDebited,
  });

  @override
  SwipeHintWrapperState createState() => SwipeHintWrapperState();
}

class SwipeHintWrapperState extends State<SwipeHintWrapper>
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
      duration: const Duration(milliseconds: 1500),
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
                  builder: (context, _) => SwipeHintContent(
                    progress: _controller.value,
                    isDebited: widget.isDebited,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
