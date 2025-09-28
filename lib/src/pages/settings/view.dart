import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/pages/settings/widgets/accounts/accounts_tab.dart';
import 'package:app/src/pages/settings/widgets/preferences/preferences_tab.dart';
import 'package:app/src/shared/widgets/tabs/swipe_tabs.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return SwipeTabs(
      tabs: [Text(tr.accounts), Text(tr.categories), Text(tr.preferences)],
      children: [
        AccountsTab(),
        Container(child: Text("Categories")),
        PreferencesTab(),
      ],
    );
  }
}
