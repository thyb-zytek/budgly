import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter/material.dart';

class PeriodSelector extends SliverPersistentHeaderDelegate {
  final Period period;
  final Period minPeriod;
  final Period maxPeriod;
  final int revision;
  final ThemeData theme;
  final ValueChanged<Period> onChanged;

  PeriodSelector({
    required this.period,
    required this.minPeriod,
    required this.maxPeriod,
    required this.revision,
    required this.theme,
    required this.onChanged,
  });

  bool get _canGoPrevious => !period.previous.isBefore(minPeriod);
  bool get _canGoNext => !period.next.isAfter(maxPeriod);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return Material(
      elevation: 0,

      color: theme.scaffoldBackgroundColor,
      child: SizedBox(
        height: maxExtent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BudglySpacing.lg,
            vertical: BudglySpacing.sm,
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
    );
  }

  @override
  double get maxExtent => 60.0;

  @override
  double get minExtent => 60.0;

  @override
  bool shouldRebuild(covariant PeriodSelector oldDelegate) {
    // The header colors come from [theme], so a theme change must rebuild the
    // header even when the period (and thus the displayed label) did not move.
    return oldDelegate.theme != theme ||
        oldDelegate.period != period ||
        oldDelegate.minPeriod != minPeriod ||
        oldDelegate.maxPeriod != maxPeriod ||
        oldDelegate.revision != revision;
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
