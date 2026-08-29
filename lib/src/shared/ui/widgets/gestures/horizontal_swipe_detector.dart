import 'package:flutter/material.dart';

enum SwipeDirection { forward, backward }

class HorizontalSwipeDetector extends StatefulWidget {
  final Widget child;
  final ValueChanged<SwipeDirection> onSwipe;

  const HorizontalSwipeDetector({
    super.key,
    required this.child,
    required this.onSwipe,
  });

  @override
  State<HorizontalSwipeDetector> createState() =>
      _HorizontalSwipeDetectorState();
}

class _HorizontalSwipeDetectorState extends State<HorizontalSwipeDetector> {
  Offset? _origin;
  Duration _startedAt = Duration.zero;

  void _onPointerDown(PointerDownEvent event) {
    _origin = event.position;
    _startedAt = event.timeStamp;
  }

  void _onPointerUp(PointerUpEvent event) {
    final origin = _origin;
    _origin = null;
    if (origin == null) return;

    final delta = event.position - origin;

    if (delta.dx.abs() < delta.dy.abs() * 1.2) return;
    if (delta.dx.abs() < 56) return;

    final elapsed = (event.timeStamp - _startedAt).inMilliseconds;
    if (elapsed > 700 && delta.dx.abs() < 140) return;

    widget.onSwipe(
      delta.dx < 0 ? SwipeDirection.forward : SwipeDirection.backward,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) => _origin = null,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
