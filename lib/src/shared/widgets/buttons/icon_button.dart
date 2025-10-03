import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:flutter/material.dart';

class BudglyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ButtonType? type;
  final bool? filled;
  final bool? smallIcon;

  const BudglyIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.type,
    this.filled = false,
    this.smallIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    TypedButtonStyle buttonColors = TypedButtonStyle(
      type: type ?? ButtonType.primary,
      theme: theme,
    );

    return IconButton(
      icon: Icon(icon, size: smallIcon! ? 32 : 42),
      onPressed: onPressed,
      alignment: Alignment.center,
      color: filled! ? buttonColors.textColor : buttonColors.iconColor,
      style: IconButton.styleFrom(
        backgroundColor: filled! ? buttonColors.backgroundColor : null,
      ),
    );
  }
}
