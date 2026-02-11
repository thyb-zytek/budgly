import 'package:app/src/models/account/account.dart';
import 'package:app/src/shared/widgets/accounts/avatar.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:app/src/shared/widgets/buttons/icon_button.dart';
import 'package:flutter/material.dart';

class AccountViewCard extends StatelessWidget {
  final Account account;
  final Color? color;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AccountViewCard({
    super.key,
    required this.account,
    this.onEdit,
    this.onDelete,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: color ?? Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ).copyWith(right: 8),
        child: Row(
          spacing: 16,
          children: [
            Avatar(
              initial: account.name[0].toUpperCase(),
              picture:
                  account.pictureUrl?.isNotEmpty == true
                      ? account.pictureUrl
                      : null,
              isLocalPicture: account.pictureUrl == null,
              backgroundColor: account.color,
              size: 52,
            ),
            Expanded(
              child: Text(account.name, style: theme.textTheme.titleLarge),
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
        ),
      ),
    );
  }
}
