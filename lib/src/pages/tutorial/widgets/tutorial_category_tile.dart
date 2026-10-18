import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_pop_in.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_view.dart';
import 'package:flutter/material.dart';

/// Category row shown in the tutorial list.
///
/// Reuses the same [CategoryView] (and card wrapper) as the settings category
/// tab so the tutorial shows the same information — notably the monthly
/// threshold — instead of a divergent list tile. The tutorial only offers
/// deletion here, so no edit action is wired.
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
    return TutorialPopIn(
      key: ValueKey(category.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: BudglyComponentStyles.cardPadding,
          child: CategoryView(category: category, onDelete: onDelete),
        ),
      ),
    );
  }
}
