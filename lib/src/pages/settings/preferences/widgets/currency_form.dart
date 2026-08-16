import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/shared/widgets/tabs/tab_switcher.dart';
import 'package:flutter/material.dart';

class CurrencyForm extends StatelessWidget {
  final String currentCurrency;
  final List<String> supportedCurrencies;
  final ValueChanged<String> onCurrencyChanged;

  const CurrencyForm({
    super.key,
    required this.currentCurrency,
    required this.supportedCurrencies,
    required this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final reversedCurrencies = supportedCurrencies.reversed.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            tr.currency,
            style: theme.textTheme.headlineSmall!.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                shape: BoxShape.rectangle,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: TabSwitcher(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                selectedIndex: reversedCurrencies.indexOf(currentCurrency),
                onTabSelected: (index) => onCurrencyChanged(reversedCurrencies[index]),
                tabs: reversedCurrencies
                    .map(
                      (currency) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          currency.currencyIcon,
                          size: 22,
                          fontWeight: currency == currentCurrency
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: currency == currentCurrency
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}