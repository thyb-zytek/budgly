import 'package:budgly/src/models/category/category_icon.dart';
import 'package:flutter/material.dart';

class CategoryIconView extends StatelessWidget {
  final CategoryIcon icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  const CategoryIconView({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color,
          ),
          child: Icon(
            icon.toIconData(),
            color: theme.colorScheme.onPrimary,
            size: size * 0.6,
          ),
        ),
      ),
    );
  }
}
