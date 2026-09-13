import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/pages/settings/preferences/preferences_provider.dart';
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
    final notifier = ref.read(preferencesProvider.notifier);

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
                Consumer(
                  builder: (context, ref, _) {
                    final mode = ref.watch(preferencesProvider.select((s) => s.mode));
                    return ThemeForm(
                      currentThemeMode: mode,
                      onThemeChanged: notifier.changeTheme,
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final locale = ref.watch(preferencesProvider.select((s) => s.locale));
                    return LocaleForm(
                      currentLocale: locale,
                      onLocaleChanged: notifier.changeLocale,
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final currency = ref.watch(preferencesProvider.select((s) => s.currency));
                    return CurrencyForm(
                      currentCurrency: currency,
                      supportedCurrencies: AppConstants.supportedCurrencies,
                      onCurrencyChanged: notifier.changeCurrency,
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final value = ref.watch(
                      preferencesProvider.select((s) => (s.currency, s.amountDecimalPlaces)),
                    );
                    return AmountForm(
                      amountDecimalPlaces: value.$2,
                      onChanged: notifier.changeAmountDecimalPlaces,
                      currency: value.$1,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
