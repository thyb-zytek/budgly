import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:app/src/shared/widgets/buttons/icon_button.dart';
import 'package:flutter/material.dart';
import 'package:app/src/models/category/category.dart';
import 'package:app/src/shared/widgets/categories/icon.dart';

class CategoryViewCard extends StatelessWidget {
  final Category category;
  final Color? color;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CategoryViewCard({
    super.key,
    required this.category,
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
            CategoryIcon(icon: category.icon!, color: category.color!),
            Expanded(
              child: Text(category.name!, style: theme.textTheme.titleLarge),
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
