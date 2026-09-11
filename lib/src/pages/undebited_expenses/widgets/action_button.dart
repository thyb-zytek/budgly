import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:flutter/material.dart';

/// Single undebited action button, shared by the per-card actions
/// ([UndebitedExpenseCard]) and the bottom bulk bar
/// ([UndebitedBulkActionBar]) so both modes render the exact same buttons.
class UndebitedActionButton extends StatelessWidget {
  final ButtonType type;
  final Widget icon;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  /// When set, forces the button to be at least [minHeight] tall.
  final double? minHeight;

  const UndebitedActionButton({
    super.key,
    required this.type,
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = type.colors(theme);
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      style: type.filledStyle(theme, dense: true).copyWith(
        minimumSize: minHeight == null
            ? null
            : WidgetStatePropertyAll(Size.fromHeight(minHeight!)),
        backgroundColor: WidgetStatePropertyAll(
          type == ButtonType.primary
              ? colors.background
              : colors.background.withAlpha(144),
        ),
      ),
      icon: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.foreground,
              ),
            )
          : icon,
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}