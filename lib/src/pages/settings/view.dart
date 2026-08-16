import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/settings/accounts/view_model.dart';
import 'package:budgly/src/pages/settings/accounts/tab.dart';
import 'package:budgly/src/pages/settings/categories/tab.dart';
import 'package:budgly/src/pages/settings/preferences/tab.dart';
import 'package:budgly/src/pages/settings/profile/tab.dart';
import 'package:budgly/src/shared/widgets/tabs/swipe_tabs.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AccountsViewModel _accountsViewModel;

  @override
  void initState() {
    super.initState();
    _accountsViewModel = AccountsViewModel();
  }

  @override
  void dispose() {
    _accountsViewModel.dispose();
    super.dispose();  
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return SwipeTabs(
        tabs: [
          Text(tr.accounts),
          Text(tr.categories),
          Text(tr.preferences),
          Text(tr.profile),
        ],
        children: [
          AccountsTab(accountsViewModel: _accountsViewModel),
          CategoriesTab(accountsViewModel: _accountsViewModel),  
          const PreferencesTab(),
          ProfileTab(),
        ],
      );
  }
}
