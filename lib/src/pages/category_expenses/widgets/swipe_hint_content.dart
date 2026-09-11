import 'dart:ui' show lerpDouble;

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class SwipeHintContent extends StatelessWidget {
  final double progress;
  final bool isDebited;

  const SwipeHintContent({
    super.key,
    required this.progress,
    required this.isDebited,
  });

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
        const pillWidth = 132.0;
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
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: BudglySpacing.xs,
                      children: [
                        Icon(
                          isDebited
                              ? Icons.swipe_left_rounded
                              : Icons.swipe_right_rounded,
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
