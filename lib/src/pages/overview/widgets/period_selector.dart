import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter/material.dart';

/// Pinned header letting the user move between budget periods.
///
/// Visually this is a soft pill control rather than plain arrows +
/// text, and the label cross-fades/slides when the period changes so
/// the swipe or tap feels responsive instead of an abrupt jump.
class PeriodSelector extends SliverPersistentHeaderDelegate {
  final Period period;
  final Period minPeriod;
  final Period maxPeriod;
  final ValueChanged<Period> onChanged;

  PeriodSelector({
    required this.period,
    required this.minPeriod,
    required this.maxPeriod,
    required this.onChanged,
  });

  bool get _canGoPrevious => !period.previous.isBefore(minPeriod);
  bool get _canGoNext => !period.next.isAfter(maxPeriod);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return Material(
      elevation: 0,
      child: SizedBox(
        height: maxExtent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 200 && _canGoPrevious) {
                onChanged(period.previous);
              } else if (velocity < -200 && _canGoNext) {
                onChanged(period.next);
              }
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(
                    icon: Icons.chevron_left_rounded,
                    enabled: _canGoPrevious,
                    onPressed: () => onChanged(period.previous),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) {
                          final slide = Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(position: slide, child: child),
                          );
                        },
                        child: Text(
                          period.label(tr.localeName),
                          key: ValueKey(period),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _NavButton(
                    icon: Icons.chevron_right_rounded,
                    enabled: _canGoNext,
                    onPressed: () => onChanged(period.next),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 60.0;

  @override
  double get minExtent => 60.0;

  @override
  bool shouldRebuild(covariant PeriodSelector oldDelegate) {
    return oldDelegate.period != period ||
        oldDelegate.minPeriod != minPeriod ||
        oldDelegate.maxPeriod != maxPeriod;
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IconButton(
      icon: Icon(icon, size: 26),
      color: theme.colorScheme.onSurface,
      disabledColor: theme.colorScheme.onSurface.withAlpha(60),
      onPressed: enabled ? onPressed : null,
    );
  }
}