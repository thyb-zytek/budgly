import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/tabs/tab_switcher.dart';
import 'package:flutter/material.dart';

class ThemeForm extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const ThemeForm({
    required this.currentThemeMode,
    required this.onThemeChanged,
    Key? key,
  }) : super(key: key);

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
                  backgroundColor: theme.colorScheme.surfaceContainer,
                  spaceBetween: 4,
                  selectedIndex: ThemeMode.values.indexOf(currentThemeMode),
                  onTabSelected: (p0) => onThemeChanged(ThemeMode.values[p0]),
                  tabs:
                      ThemeMode.values
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                spacing: 8,
                                children: [
                                  Icon(
                                    _getIcon(e),
                                    size: 22,
                                  color:
                                      e == currentThemeMode
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                ),
                                Text(
                                  _getThemeName(e, tr),
                                  style: TextStyle(
                                    fontSize:
                                        theme.textTheme.bodySmall!.fontSize!,
                                    fontFamily:
                                        theme.textTheme.bodySmall!.fontFamily,
                                  ),
                                ),
                              ],
                            )),
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
