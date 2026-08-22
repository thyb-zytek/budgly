import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_editing_data.dart';
import 'package:flutter/material.dart';

abstract class CategoryFormViewModel implements ChangeNotifier {
  CategoryEditingData get categoryEditingData;
  Future<void> createCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> removeCategory(Category category);
  void cancelEdit();
}
