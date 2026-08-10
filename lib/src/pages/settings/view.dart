import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/settings/widgets/accounts/accounts_tab.dart';
import 'package:budgly/src/pages/settings/widgets/accounts/view_model.dart';
import 'package:budgly/src/pages/settings/widgets/categories/categories_tab.dart';
import 'package:budgly/src/pages/settings/widgets/categories/view_model.dart';
import 'package:budgly/src/pages/settings/widgets/preferences/preferences_tab.dart';
import 'package:budgly/src/pages/settings/widgets/user/user_tab.dart';
import 'package:budgly/src/pages/settings/widgets/user/view_model.dart';
import 'package:budgly/src/shared/widgets/tabs/swipe_tabs.dart';
import 'package:budgly/src/core/stores/settings.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AccountsViewModel _accountsViewModel;
  late final CategoriesViewModel _categoriesViewModel;
  late final UserViewModel _userViewModel;

  @override
  void initState() {
    super.initState();
    _accountsViewModel = AccountsViewModel();
    _categoriesViewModel = CategoriesViewModel();
    _userViewModel = UserViewModel();
  }

  @override
  void dispose() {
    _accountsViewModel.dispose();
    _categoriesViewModel.dispose();
    _userViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return SettingsStore(
      accountsViewModel: _accountsViewModel,
      categoriesViewModel: _categoriesViewModel,
      child: SwipeTabs(
        tabs: [
          Text(tr.accounts),
          Text(tr.categories),
          Text(tr.preferences),
          Text(tr.user),
        ],
        children: [
          AccountsTab(accountsViewModel: _accountsViewModel),
          CategoriesTab(
            accountsViewModel: _accountsViewModel,
            categoriesViewModel: _categoriesViewModel,
          ),
          const PreferencesTab(),
          UserTab(viewModel: _userViewModel),
        ],
      ),
    );
  }
}
