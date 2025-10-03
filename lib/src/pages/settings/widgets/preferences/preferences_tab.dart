import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/pages/settings/widgets/preferences/view_model.dart';
import 'package:app/src/pages/settings/widgets/preferences/currency_form.dart';
import 'package:app/src/pages/settings/widgets/preferences/locale_form.dart';
import 'package:app/src/pages/settings/widgets/preferences/theme_form.dart';
import 'package:flutter/material.dart';

class PreferencesTab extends StatefulWidget {
  const PreferencesTab({
    super.key,
  });

  @override
  State<PreferencesTab> createState() => _PreferencesTabState();
}

class _PreferencesTabState extends State<PreferencesTab> {
  final PreferencesViewModel _viewModel = PreferencesViewModel();


  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 28, left: 16),
            child: Text(
              tr.appearance,
              textAlign: TextAlign.start,
              style: theme.textTheme.headlineLarge!
            ),
          ),
          ThemeForm(
            currentThemeMode: _viewModel.mode,
            onThemeChanged: _viewModel.changeTheme,
          ),
          LocaleForm(
            currentLocale: _viewModel.locale,
            onLocaleChanged: _viewModel.changeLocale,
          ),
          CurrencyForm(),
        ],
      ),
    );
  }
}
