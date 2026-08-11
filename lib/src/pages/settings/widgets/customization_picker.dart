import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/shared/widgets/buttons/button.dart';
import 'package:budgly/src/shared/widgets/buttons/constants.dart';
import 'package:budgly/src/shared/widgets/tabs/tab.dart';
import 'package:budgly/src/shared/widgets/tabs/tab_switcher.dart';
import 'package:flutter/material.dart';

class CustomizationPicker extends StatefulWidget {
  final String title;
  final Widget previewWidget;
  final List<TabTitle> tabTitles;
  final List<Widget> tabs;
  final VoidCallback onValidate;
  final VoidCallback onCancel;

  const CustomizationPicker({
    super.key,
    required this.title,
    required this.previewWidget,
    required this.tabTitles,
    required this.tabs,
    required this.onValidate,
    required this.onCancel,
  });

  @override
  State<CustomizationPicker> createState() => _CustomizationPickerState();
}

class _CustomizationPickerState extends State<CustomizationPicker> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 24,
      children: [
        Text(
          widget.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        widget.previewWidget,
        TabSwitcher(
          selectedIndex: _currentIndex,
          onTabSelected: _onTabSelected,
          tabs: widget.tabTitles.map((tab) {
            bool isSelected = _currentIndex == widget.tabTitles.indexOf(tab);
            return Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(
                  tab.icon,
                  size: 17,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                Text(
                  tab.title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            ),
            child: _currentIndex == 0 ? widget.tabs[0] : widget.tabs[1],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: BudglyButton(
                  text: tr.cancel,
                  type: ButtonType.error,
                  onPressed: widget.onCancel,
                  dense: true,
                ),
              ),
              Expanded(
                child: BudglyButton(
                  text: tr.validate,
                  onPressed: widget.onValidate,
                  dense: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
