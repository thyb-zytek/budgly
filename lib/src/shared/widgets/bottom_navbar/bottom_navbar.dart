import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNavBar extends StatefulWidget {
  final StatefulNavigationShell child;

  const BottomNavBar({super.key, required this.child});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  @override
  Widget build(BuildContext context) {
    AppLocalizations tr = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(child: widget.child),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: widget.child.currentIndex,
        selectedItemColor: theme.colorScheme.primary,
        iconSize: 22,
        selectedFontSize:
            theme.textTheme.labelLarge?.fontSize != null
                ? theme.textTheme.labelLarge!.fontSize!
                : 16,
        unselectedFontSize:
            theme.textTheme.labelLarge?.fontSize != null
                ? theme.textTheme.labelLarge!.fontSize!
                : 16,
        onTap: (index) {
          widget.child.goBranch(
            index,
            initialLocation: index == widget.child.currentIndex,
          );
          setState(() {});
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: tr.overviewLink,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: tr.settingsLink,
          ),
        ],
      ),
    );
  }
}
