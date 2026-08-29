import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:flutter/material.dart';

class CategoryIconView extends StatelessWidget {
  final CategoryIcon icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const CategoryIconView({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
    this.onTap,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
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
            if (showEditBadge && onTap != null)
              Positioned(
                bottom: -4,
                right: -4,
                child: Material(
                  color: theme.colorScheme.primary,
                  shape: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(BudglySpacing.xs),
                    child: Icon(
                      Icons.edit_rounded,
                      size: size < 60 ? 11 : 13,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
