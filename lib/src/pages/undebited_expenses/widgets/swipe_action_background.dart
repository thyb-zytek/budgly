import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// A single action (icon + label) surfaced on an
/// [UndebitedSwipeActionBackground] while the card is being dragged.
class UndebitedSwipeBackgroundAction {
  final IconData icon;
  final String label;

  const UndebitedSwipeBackgroundAction({
    required this.icon,
    required this.label,
  });
}

/// Colored background revealed behind an [UndebitedExpenseCard] while it is
/// being dragged, naming the action(s) a completed swipe would trigger.
///
/// Unlike a bare icon, the background explicitly shows what will happen:
/// a single action (e.g. "debit on the original period") is rendered on one
/// line with its icon, while a multi-action background (the sheet opened by a
/// right swipe) stacks one line per action so the user can see exactly what
/// will happen before letting go. Content is anchored to the edge the card
/// slides away from, so it becomes readable as soon as the swipe starts.
class UndebitedSwipeActionBackground extends StatelessWidget {
  /// Where within the background the actions are anchored. Leading (right
  /// swipe) anchors left, trailing (left swipe) anchors right.
  final Alignment alignment;

  final Color color;
  final Color foregroundColor;

  final List<UndebitedSwipeBackgroundAction> actions;

  const UndebitedSwipeActionBackground({
    super.key,
    required this.alignment,
    required this.color,
    required this.foregroundColor,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLeading = alignment == Alignment.centerLeft;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BudglyRadius.large,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: actions.length == 1
          ? _buildSingleAction(theme, isLeading)
          : _buildMultipleActions(theme, isLeading),
    );
  }

  Widget _buildSingleAction(ThemeData theme, bool isLeading) {
    final action = actions.single;
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: isLeading
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        Icon(action.icon, size: 22, color: foregroundColor),
        SizedBox(width: BudglySpacing.sm),
        Flexible(
          child: Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: isLeading ? TextAlign.start : TextAlign.end,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleActions(ThemeData theme, bool isLeading) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isLeading
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      spacing: BudglySpacing.xs,
      children: [
        for (final action in actions)
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: isLeading
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: [
              Icon(action.icon, size: 16, color: foregroundColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}