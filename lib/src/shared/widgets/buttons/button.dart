import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:flutter/material.dart';

class BudglyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType? type;
  final IconData? leadingIcon;

  const BudglyButton({
    super.key,
    this.type,
    this.onPressed,
    required this.text,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    TypedButtonStyle buttonColors = TypedButtonStyle(
      type: type ?? ButtonType.primary,
      theme: theme,
    );

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: buttonColors.backgroundColor,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        iconSize: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      iconAlignment: IconAlignment.start,
      icon:
          leadingIcon != null
              ? Icon(leadingIcon, color: buttonColors.textColor)
              : null,
      label: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: buttonColors.textColor,
        ),
      ),
    );
  }
}
