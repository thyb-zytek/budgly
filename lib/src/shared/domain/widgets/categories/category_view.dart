import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
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
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 32),
                  onPressed: onEdit,
                  color: theme.colorScheme.primary,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_rounded, size: 32),
                  onPressed: onDelete,
                  color: theme.colorScheme.error,
                ),
            ],
          ),
      ],
    );
  }
}
