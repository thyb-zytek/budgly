import 'package:app/src/models/category/category_icon.dart';
import 'package:flutter/material.dart';

class CategoryEditingData {
  TextEditingController nameController;
  Color color;
  CategoryIcon icon;

  CategoryEditingData({
    required this.nameController,
    required this.color,
    required this.icon,
  });
}