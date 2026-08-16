import 'package:budgly/src/models/category/category.dart';

class CategoryExpenseSummary {
  final Category category;
  final double total;
  final double debited;
  final double undebited;
  final int undebitedCount;

  const CategoryExpenseSummary({
    required this.category,
    required this.total,
    required this.debited,
    required this.undebited,
    required this.undebitedCount,
  });
}