import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/pages/settings/widgets/accounts/accounts_tab.dart';
import 'package:app/src/pages/settings/widgets/accounts/view_model.dart';
import 'package:app/src/pages/settings/widgets/categories/categories_tab.dart';
import 'package:app/src/pages/settings/widgets/categories/view_model.dart';
import 'package:app/src/pages/settings/widgets/preferences/preferences_tab.dart';
import 'package:app/src/pages/settings/widgets/user/user_tab.dart';
import 'package:app/src/pages/settings/widgets/user/view_model.dart';
import 'package:app/src/shared/widgets/tabs/swipe_tabs.dart';
import 'package:app/src/stores/settings.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    final accountsViewModel = AccountsViewModel();
    final categoriesViewModel = CategoriesViewModel();
    final userViewModel = UserViewModel();

    return SettingsStore(
      accountsViewModel: accountsViewModel,
      categoriesViewModel: categoriesViewModel,
      child: SwipeTabs(
        tabs: [
          Text(tr.accounts),
          Text(tr.categories),
          Text(tr.preferences),
          Text(tr.user),
        ],
        children: [
          AccountsTab(accountsViewModel: accountsViewModel),
          CategoriesTab(
            accountsViewModel: accountsViewModel,
            categoriesViewModel: categoriesViewModel,
          ),
          PreferencesTab(),
          UserTab(viewModel: userViewModel),
        ],
      ),
    );
  }
}
