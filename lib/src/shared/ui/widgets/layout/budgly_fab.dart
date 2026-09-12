import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class BudglyFab extends StatelessWidget {
  final String heroTag;
  final String? label;
  final VoidCallback onPressed;
  final bool disabled;

  const BudglyFab({
    super.key,
    required this.heroTag,
    required this.onPressed,
    this.label,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fabTheme = theme.floatingActionButtonTheme;
    final hasLabel = label != null;

    final backgroundColor =
        fabTheme.backgroundColor ?? theme.colorScheme.primary;
    final foregroundColor =
        fabTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final shape =
        fabTheme.shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        );

    Widget fab = Hero(
      tag: heroTag,
      child: Material(
        color: backgroundColor,
        shape: shape,
        elevation: fabTheme.elevation ?? 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: shape,
          onTap: disabled ? null : onPressed,
          child: Container(
            height: BudglyComponentStyles.fabSize,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: BudglyComponentStyles.fabIconSize,
                  color: foregroundColor,
                ),
                if (hasLabel)
                  Padding(
                    padding: EdgeInsets.only(left: BudglySpacing.xs, right: BudglySpacing.md),
                    child: Text(
                      label!,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (disabled) {
      fab = IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: 0.4,
          child: fab,
        ),
      );
    }

    return fab;
  }
}
