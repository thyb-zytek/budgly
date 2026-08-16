import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/shared/widgets/categories/category_view.dart';
import 'package:budgly/src/shared/widgets/selector/selector.dart';
import 'package:flutter/material.dart';

class CategorySelector extends StatelessWidget {
  final List<Category> categories;
  final Category? selectedCategory;
  final ValueChanged<Category> onSelect;

  const CategorySelector({
    super.key,
    required this.categories,
    this.selectedCategory,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final validCategories = categories
        .where((category) => category.id != null)
        .toList();

    return Selector<Category>(
      items: validCategories,
      selectedItem: selectedCategory,
      onSelect: onSelect,
      maxHeight: 300,
      backgroundColor: Theme.of(context).colorScheme.surface,
      itemBuilder: (context, category) => CategoryView(
        category: category,
        color: Colors.transparent,
      ),
    );
  }
}