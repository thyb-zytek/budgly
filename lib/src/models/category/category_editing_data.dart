import 'package:budgly/src/models/category/category_icon.dart';
import 'package:flutter/material.dart';

class CategoryEditingData {
  final TextEditingController nameController;
  Color color;
  CategoryIcon icon;
  List<CategoryIcon> availableIcons;

  CategoryEditingData({
    required this.nameController,
    required this.color,
    required this.icon,
    required this.availableIcons,
  });
}