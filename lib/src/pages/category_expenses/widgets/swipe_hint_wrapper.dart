import 'dart:async';

import 'dart:ui' show lerpDouble;

import 'package:budgly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Wraps the first expense row and periodically plays a short animation
/// (every few seconds) showing that a row can be swiped. The travel
/// direction follows [isDebited]: towards the right when pending (mark as
/// debited), towards the left once debited (undo). The hint stops as soon
/// as the user interacts with the row ([stop] is invoked by the tile).
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
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _SwipeHintContent(
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

class _SwipeHintContent extends StatelessWidget {
  final double progress;
  final bool isDebited;

  const _SwipeHintContent({required this.progress, required this.isDebited});

  /// Fades the pill in on the first fifth of the animation and out on the
  /// last fifth.
  static double _fade(double t) {
    if (t < 0.2) return t / 0.2;
    if (t > 0.8) return (1 - t) / 0.2;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final t = Curves.easeInOutCubic.transform(progress);

    return LayoutBuilder(
      builder: (context, constraints) {
        const pillWidth = 120.0;
        final maxLeft = (constraints.maxWidth - pillWidth).clamp(
          0.0,
          double.infinity,
        );
        final start = isDebited ? 0.94 : 0.22;
        final end = isDebited ? 0.06 : 0.78;
        final left = (lerpDouble(start, end, t) ?? 0) * constraints.maxWidth;
        final opacity = _fade(t);

        return Stack(
          children: [
            Positioned(
              left: left.clamp(0.0, maxLeft),
              top: 0,
              bottom: 0,
              width: pillWidth,
              child: Center(
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        Icon(
                          isDebited
                              ? Icons.swipe_left_rounded
                              : Icons.swipe_right_rounded,
                          size: 16,
                          color: theme.colorScheme.onInverseSurface,
                        ),
                        Text(
                          tr.swipeHint,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
