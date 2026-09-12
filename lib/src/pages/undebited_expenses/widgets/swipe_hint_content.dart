import 'dart:ui' show lerpDouble;

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// Animated pill demonstrating both swipe directions available on
/// [UndebitedExpenseCard]: the first half of [progress] slides right (as a
/// right-swipe would) and the second half slides back left (as a left-swipe
/// would), so a single cycle teaches both gestures.
class UndebitedSwipeHintContent extends StatelessWidget {
  final double progress;

  const UndebitedSwipeHintContent({super.key, required this.progress});

  static double _fade(double t) {
    if (t < 0.15) return t / 0.15;
    if (t > 0.85) return (1 - t) / 0.15;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    // First half of the cycle: pill starts centered and slides toward the
    // right edge, pointing right (mirrors a right swipe).
    // Second half: pill starts near the right edge and slides back toward
    // the left edge, pointing left (mirrors a left swipe).
    final isFirstHalf = progress < 0.5;
    final localT = isFirstHalf ? progress / 0.5 : (progress - 0.5) / 0.5;
    final t = Curves.easeInOutCubic.transform(localT);
    final start = isFirstHalf ? 0.38 : 0.82;
    final end = isFirstHalf ? 0.82 : 0.18;
    final icon = isFirstHalf
        ? Icons.swipe_right_rounded
        : Icons.swipe_left_rounded;
    final opacity = _fade(localT);

    return LayoutBuilder(
      builder: (context, constraints) {
        const pillWidth = 132.0;
        final maxLeft = (constraints.maxWidth - pillWidth).clamp(
          0.0,
          double.infinity,
        );
        final left = (lerpDouble(start, end, t) ?? 0) * constraints.maxWidth;

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
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: BudglySpacing.xs,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: theme.colorScheme.onInverseSurface,
                        ),
                        Flexible(
                          child: Text(
                            tr.swipeHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onInverseSurface,
                              fontWeight: FontWeight.w700,
                            ),
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
