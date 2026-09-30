import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/pages/settings/preferences/widgets/amount_form.dart';
import 'package:budgly/src/pages/settings/preferences/widgets/currency_form.dart';
import 'package:budgly/src/pages/settings/preferences/widgets/locale_form.dart';
import 'package:budgly/src/pages/settings/preferences/widgets/theme_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PreferencesTab extends ConsumerWidget {
  const PreferencesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final profileNotifier = ref.read(profileSessionProvider.notifier);
    final profile = ref.watch(profileSessionProvider);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: BudglySpacing.sm,
        vertical: BudglySpacing.lg,
      ),
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
                ThemeForm(
                  currentThemeMode: profile.themeMode,
                  onThemeChanged: (value) =>
                      profileNotifier.savePreferences(themeMode: value),
                ),
                LocaleForm(
                  currentLocale: profile.locale,
                  onLocaleChanged: (value) =>
                      profileNotifier.savePreferences(locale: value),
                ),
                CurrencyForm(
                  currentCurrency: profile.currency,
                  supportedCurrencies: AppConstants.supportedCurrencies,
                  onCurrencyChanged: (value) =>
                      profileNotifier.savePreferences(currency: value),
                ),
                AmountForm(
                  amountDecimalPlaces: profile.amountDecimalPlaces,
                  onChanged: (value) => profileNotifier.savePreferences(
                    amountDecimalPlaces: value,
                  ),
                  currency: profile.currency,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
