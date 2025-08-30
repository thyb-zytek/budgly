import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/pages/settings/widgets/currency_form.dart';
import 'package:app/src/pages/settings/widgets/locale_form.dart';
import 'package:app/src/pages/settings/widgets/theme_form.dart';
import 'package:flutter/material.dart';

class PreferencesForm extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final Locale currentLocale;
  final void Function(ThemeMode) changeTheme;
  final void Function(Locale) changeLocale;

  const PreferencesForm({
    super.key,
    required this.changeTheme,
    required this.currentThemeMode,
    required this.changeLocale,
    required this.currentLocale,
  });

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
              style: theme.textTheme.headlineLarge!.copyWith(
                decoration: TextDecoration.underline,
                decorationThickness: 1.2,
                decorationColor: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          ThemeForm(
            currentThemeMode: currentThemeMode,
            onThemeChanged: changeTheme,
          ),
          LocaleForm(
            currentLocale: currentLocale,
            onLocaleChanged: changeLocale,
          ),
          CurrencyForm(),
        ],
      ),
    );
  }
}
