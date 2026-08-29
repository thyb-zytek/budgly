import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
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

    return ColoredBox(
      color: color ?? Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            spacing: 16,
            children: [
              Avatar(
                initial: account.initial,
                picture: account.pictureUrl?.isNotEmpty == true
                    ? account.pictureUrl
                    : null,
                isLocalPicture: account.pictureUrl == null ||
                    account.pictureUrl!.startsWith('/') ||
                    account.pictureUrl!.startsWith('file://'),
                backgroundColor: account.color,
                size: 52,
              ),
              Padding(
                padding: const EdgeInsets.only(right: BudglySpacing.sm),
                child: Text(account.name, style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          if (onEdit != null || onDelete != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (onEdit != null)
                  IconButton(
                    icon: Icon(Icons.edit_rounded, size: 32),
                    onPressed: onEdit,
                    color: theme.colorScheme.primary,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_rounded, size: 32),
                    onPressed: onDelete,
                    color: theme.colorScheme.error,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
