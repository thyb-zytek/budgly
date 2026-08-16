import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/settings/preferences/view_model.dart';
import 'package:budgly/src/pages/settings/preferences/widgets/currency_form.dart';
import 'package:budgly/src/pages/settings/preferences/widgets/locale_form.dart';
import 'package:budgly/src/pages/settings/preferences/widgets/theme_form.dart';
import 'package:flutter/material.dart';

class PreferencesTab extends StatefulWidget {
  const PreferencesTab({super.key});

  @override
  State<PreferencesTab> createState() => _PreferencesTabState();
}

class _PreferencesTabState extends State<PreferencesTab> {
  final PreferencesViewModel _viewModel = PreferencesViewModel();

  @override
  void dispose() {
    // Manquait : sans ça, le listener posé sur ProfileService dans le
    // constructeur du view model n'était jamais retiré.
    _viewModel.dispose();
    super.dispose();
  }

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
              style: theme.textTheme.headlineLarge!,
            ),
          ),
          // Écoute le view model : les 3 formulaires modifient l'état
          // via ProfileService, donc il faut se reconstruire quand il
          // notifie, sinon on affiche une valeur figée au premier build.
          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ThemeForm(
                    currentThemeMode: _viewModel.mode,
                    onThemeChanged: _viewModel.changeTheme,
                  ),
                  LocaleForm(
                    currentLocale: _viewModel.locale,
                    onLocaleChanged: _viewModel.changeLocale,
                  ),
                  CurrencyForm(
                    currentCurrency: _viewModel.currency,
                    supportedCurrencies: _viewModel.supportedCurrencies,
                    onCurrencyChanged: _viewModel.changeCurrency,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}