import 'package:flutter/material.dart';

/// Trailing edit/delete icon-button pair used by list-item widgets that
/// represent an editable entity (account, category, ...).
///
/// Returns [SizedBox.shrink] when neither callback is provided, so callers
/// can use it unconditionally instead of guarding with an `if`.
class EditDeleteActions extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final double iconSize;

  const EditDeleteActions({
    super.key,
    this.onEdit,
    this.onDelete,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    if (onEdit == null && onDelete == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (onEdit != null)
          IconButton(
            icon: Icon(Icons.edit_rounded, size: iconSize),
            onPressed: onEdit,
            color: theme.colorScheme.primary,
          ),
        if (onDelete != null)
          IconButton(
            icon: Icon(Icons.delete_rounded, size: iconSize),
            onPressed: onDelete,
            color: theme.colorScheme.error,
          ),
      ],
    );
  }
}
