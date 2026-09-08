import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/shared/ui/widgets/actions/edit_delete_actions.dart';
import 'package:flutter/material.dart';

class CategoryView extends StatelessWidget {
  final Category category;
  final Color? color;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CategoryView({
    super.key,
    required this.category,
    this.onEdit,
    this.onDelete,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      spacing: 16,
      children: [
        if (category.icon != null)
          CategoryIconView(
            icon: category.icon!,
            color: category.color ?? Colors.grey,
          )
        else
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: category.color ?? Colors.grey,
            ),
            child: Icon(
              Icons.category,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 48 * 0.6,
            ),
          ),
        Expanded(
          child: Text(
            category.name ?? '',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onEdit != null || onDelete != null)
          EditDeleteActions(onEdit: onEdit, onDelete: onDelete),
      ],
    );
  }
}
