import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_pop_in.dart';
import 'package:flutter/material.dart';

class TutorialCategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onDelete;

  const TutorialCategoryTile({
    super.key,
    required this.category,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TutorialPopIn(
      key: ValueKey(category.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: category.icon == null
              ? null
              : CategoryIconView(
                  icon: category.icon!,
                  color: category.color ?? theme.colorScheme.primary,
                  size: 36,
                ),
          title: Text(
            category.name ?? '',
            style: theme.textTheme.titleMedium,
          ),
          trailing: IconButton(
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            icon: const Icon(Icons.delete_rounded, size: 20),
            onPressed: onDelete,
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}
