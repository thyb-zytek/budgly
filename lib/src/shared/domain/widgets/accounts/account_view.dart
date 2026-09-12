import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/shared/ui/widgets/actions/edit_delete_actions.dart';
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
          Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
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
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(right: BudglySpacing.sm),
                    child: Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null)
            EditDeleteActions(onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}
