import 'package:flutter/material.dart';

class TabSwitcher extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTabSelected;
  final List<Widget> tabs;
  final Color? backgroundColor;
  final double? spaceBetween;

  const TabSwitcher({
    Key? key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.tabs,
    this.backgroundColor,
    this.spaceBetween,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50.0),
        color: backgroundColor ?? theme.colorScheme.outline.withAlpha(50),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        spacing: spaceBetween ?? 8.0,
        children: List.generate(tabs.length, (index) {
          return GestureDetector(
            onTap: () => onTabSelected(index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50.0),
                color:
                    selectedIndex == index
                        ? theme.colorScheme.surface
                        : Colors.transparent,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color:
                        selectedIndex == index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                    fontWeight:
                        selectedIndex == index
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                  child: tabs[index],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
