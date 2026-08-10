import 'package:budgly/src/models/category/category_icon.dart' as cim;
import 'package:budgly/src/shared/widgets/categories/icon_picker.dart';
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
    this.size = 48,
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
                  ? showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: DraggableScrollableSheet(
                          initialChildSize: 0.5,
                          minChildSize: 0.4,
                          maxChildSize: 0.8,
                          expand: false,
                          builder: (context, scrollController) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: Offset(0, -5),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Handle for dragging
                                  Container(
                                    margin: EdgeInsets.symmetric(vertical: 12),
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.outlineVariant,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  // Title
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    child: Text(
                                      'Choose Icon',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                  ),
                                  // Icon picker content
                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: scrollController,
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                      child: IconPicker(
                                        color: color,
                                        availableIcons: availableIcons,
                                        icon: icon,
                                        onChangeColor: onChangeColor!,
                                        onChangeIcon: onChangeIcon!,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  )
                  : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(12),
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon.toIconData(),
          color: theme.colorScheme.onPrimary,
          size: size * 0.6,
        ),
      ),
    );
  }
}
