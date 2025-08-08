import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/tabs/tab_switcher.dart';
import 'package:flutter/material.dart';

class PreferencesForm extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final void Function(ThemeMode?) changeTheme;

  const PreferencesForm({
    super.key,
    required this.changeTheme,
    required this.currentThemeMode,
  });

  @override
  State<PreferencesForm> createState() => _PreferencesFormState();
}

class _PreferencesFormState extends State<PreferencesForm> {
  late int _selectedIndex;

  initState() {
    super.initState();
    _selectedIndex = ThemeMode.values.indexOf(widget.currentThemeMode);
  }

  IconData _getIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.phone_android_rounded,
    };
  }

  String _getThemeName(ThemeMode mode) {
    AppLocalizations tr = AppLocalizations.of(context)!;

    return switch (mode) {
      ThemeMode.light => tr.light,
      ThemeMode.dark => tr.dark,
      ThemeMode.system => tr.system,
    };
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations tr = AppLocalizations.of(context)!;
    ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: EdgeInsets.only(bottom: 24), child: Text(
            tr.preferences,
            style: theme.textTheme.headlineLarge,
          )),
          Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text(
              tr.appearance,
              style: theme.textTheme.headlineSmall!.copyWith(
                decoration: TextDecoration.underline,
                decorationThickness: 1.2,
                decorationColor: theme.colorScheme.outlineVariant
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Text(tr.theme, style: theme.textTheme.titleSmall),
              ),
              TabSwitcher(
                backgroundColor: theme.colorScheme.surfaceContainer,
                spaceBetween: 2,
                selectedIndex: _selectedIndex,
                onTabSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                    widget.changeTheme(ThemeMode.values[index]);
                  });
                },
                tabs:
                    ThemeMode.values
                        .map(
                          (e) => Row(
                            spacing: 4,
                            children: [
                              Icon(
                                _getIcon(e),
                                size: 20,
                                color:
                                    _selectedIndex ==
                                            ThemeMode.values.indexOf(e)
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                              ),
                              Text(
                                _getThemeName(e),
                                style: TextStyle(
                                  fontSize: theme.textTheme.bodySmall!.fontSize,
                                  fontFamily:
                                      theme.textTheme.bodySmall!.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
