import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/settings/preferences/view_model.dart';
import 'package:budgly/src/pages/settings/preferences/widgets/amount_form.dart';
import 'package:budgly/src/pages/settings/preferences/widgets/currency_form.dart';
import 'package:budgly/src/pages/settings/preferences/widgets/locale_form.dart';
import 'package:budgly/src/pages/settings/preferences/widgets/theme_form.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:budgly/src/core/view_models/view_model_selector.dart';

class PreferencesTab extends StatefulWidget {
  const PreferencesTab({super.key});

  @override
  State<PreferencesTab> createState() => _PreferencesTabState();
}

class _PreferencesTabState extends State<PreferencesTab> {
  final PreferencesViewModel _viewModel = PreferencesViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: BudglySpacing.sm, vertical: BudglySpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 28, left: BudglySpacing.lg),
              child: Text(
                tr.appearance,
                textAlign: TextAlign.start,
                style: theme.textTheme.headlineLarge!,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ViewModelSelector(
                  model: _viewModel,
                  selector: (model) => model.mode,
                  builder: (context, mode) => ThemeForm(
                    currentThemeMode: mode,
                    onThemeChanged: _viewModel.changeTheme,
                  ),
                ),
                ViewModelSelector(
                  model: _viewModel,
                  selector: (model) => model.locale,
                  builder: (context, locale) => LocaleForm(
                    currentLocale: locale,
                    onLocaleChanged: _viewModel.changeLocale,
                  ),
                ),
                ViewModelSelector(
                  model: _viewModel,
                  selector: (model) => model.currency,
                  builder: (context, currency) => CurrencyForm(
                    currentCurrency: currency,
                    supportedCurrencies: _viewModel.supportedCurrencies,
                    onCurrencyChanged: _viewModel.changeCurrency,
                  ),
                ),
                ViewModelSelector(
                  model: _viewModel,
                  selector: (model) => (model.currency, model.amountDecimalPlaces),
                  builder: (context, value) => AmountForm(
                    amountDecimalPlaces: value.$2,
                    onChanged: _viewModel.changeAmountDecimalPlaces,
                    currency: value.$1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
