import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/shared/widgets/categories/category_icon_view.dart';
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
        CategoryIconView(icon: category.icon!, color: category.color!),
        Expanded(
          child: Text(category.name!, style: theme.textTheme.titleLarge),
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
                  color: ButtonType.primary.iconButtonColor(theme),
                  style: ButtonType.primary.iconButtonStyle(theme),
                ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_rounded, size: 32),
                  onPressed: onDelete,
                  color: ButtonType.error.iconButtonColor(theme),
                  style: ButtonType.error.iconButtonStyle(theme),
                ),
            ],
          ),
      ],
    );
  }
}
