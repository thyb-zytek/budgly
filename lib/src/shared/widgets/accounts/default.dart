import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/shared/widgets/avatar/avatar.dart';
import 'package:budgly/src/shared/widgets/buttons/constants.dart';
import 'package:budgly/src/shared/widgets/buttons/icon_button.dart';
import 'package:flutter/material.dart';

class AccountView extends StatelessWidget {
  final Account account;
  final Color? color;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AccountView({
    super.key,
    required this.account,
    this.onEdit,
    this.onDelete,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          spacing: 16,
          children: [
            Avatar(
              initial: account.initial,
              picture:
                  account.pictureUrl?.isNotEmpty == true
                      ? account.pictureUrl
                      : null,
              isLocalPicture: account.pictureUrl == null,
              backgroundColor: account.color,
              size: 52,
            ),
            Text(account.name, style: theme.textTheme.titleLarge),
          ],
        ),
        if (onEdit != null || onDelete != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (onEdit != null)
                BudglyIconButton(
                  icon: Icons.edit_rounded,
                  type: ButtonType.primary,
                  smallIcon: true,
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                BudglyIconButton(
                  icon: Icons.delete_rounded,
                  type: ButtonType.error,
                  smallIcon: true,
                  onPressed: onDelete,
                ),
            ],
          ),
      ],
    );
  }
}
