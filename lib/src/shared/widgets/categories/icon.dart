import 'package:app/src/models/category/category_icon.dart' as cim;
import 'package:app/src/shared/widgets/categories/icon_picker.dart';
import 'package:flutter/material.dart';

class CategoryIcon extends StatelessWidget {
  final cim.CategoryIcon icon;
  final Color color;
  final double size;
  final List<cim.CategoryIcon> availableIcons;
  final void Function(Color color)? onChangeColor;
  final void Function(cim.CategoryIcon icon)? onChangeIcon;

  const CategoryIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 32,
    this.onChangeColor,
    this.onChangeIcon,
    this.availableIcons = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap:
          () =>
              onChangeColor != null && onChangeIcon != null
                  ? showDialog(
                    context: context,
                    builder:
                        (context) => IconPicker(
                          color: color,
                          availableIcons: availableIcons,
                          icon: icon,
                          onChangeColor: onChangeColor!,
                          onChangeIcon: onChangeIcon!,
                        ),
                  )
                  : null,
      child: Container(
        width: size + 16,
        height: size + 16,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(8),
          color: color,
        ),
        child: Icon(
          icon.iconData,
          color: theme.colorScheme.onPrimary,
          size: size,
        ),
      ),
    );
  }
}
