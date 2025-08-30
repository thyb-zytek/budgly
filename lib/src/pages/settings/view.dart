import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/pages/settings/widgets/accounts_form.dart';
import 'package:app/src/pages/settings/widgets/categories_form.dart';
import 'package:app/src/shared/widgets/tabs/swipe_tabs.dart';
import 'package:flutter/material.dart';

import 'view_model.dart';
import 'widgets/preferences_form.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsViewModel _viewModel;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = SettingsViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return SwipeTabs(
          initialIndex: _currentIndex,
          onIndexChanged: (index) => setState(() => _currentIndex = index),
          tabs: [
            Text(tr.accounts),
            Text(tr.categories),
            Text(tr.preferences),
          ],
          children: [
            AccountsForm(
              accounts: _viewModel.accounts.items,
              onAdd: _viewModel.accounts.add,
              onEdit: _viewModel.accounts.update,
              onDelete: _viewModel.accounts.remove,
            ),
            CategoriesForm(
              categories: _viewModel.categories.items,
              onAdd: _viewModel.categories.add,
              onEdit: _viewModel.categories.update,
              onDelete: _viewModel.categories.remove,
            ),
            PreferencesForm(
              currentThemeMode: _viewModel.preferences.mode,
              currentLocale: _viewModel.preferences.locale,
              changeTheme: _viewModel.preferences.changeTheme,
              changeLocale: _viewModel.preferences.changeLocale,
            ),
          ],
        );
      },
    );
  }
}
