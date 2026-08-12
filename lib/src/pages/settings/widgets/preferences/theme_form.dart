import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/shared/widgets/tabs/tab_switcher.dart';
import 'package:flutter/material.dart';

class ThemeForm extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const ThemeForm({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  IconData _getIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.phone_android_rounded,
    };
  }

  String _getThemeName(ThemeMode mode, AppLocalizations tr) {
    return switch (mode) {
      ThemeMode.light => tr.light,
      ThemeMode.dark => tr.dark,
      ThemeMode.system => tr.system,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr.theme,
            textAlign: TextAlign.start,
            style: theme.textTheme.headlineSmall!.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TabSwitcher(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  spaceBetween: 8,
                  selectedIndex: ThemeMode.values.indexOf(currentThemeMode),
                  onTabSelected: (p0) => onThemeChanged(ThemeMode.values[p0]),
                  tabs: ThemeMode.values
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            spacing: 4,
                            children: [
                              Icon(
                                _getIcon(e),
                                size: 22,
                                color: e == currentThemeMode
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant.withAlpha(156),
                              ),
                              Text(
                                _getThemeName(e, tr),
                                style: theme.textTheme.bodySmall!.copyWith(
                                  fontWeight: e == currentThemeMode
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: e == currentThemeMode
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
