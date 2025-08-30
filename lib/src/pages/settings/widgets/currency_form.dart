import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/services/preferences_service.dart';
import 'package:app/src/shared/widgets/tabs/tab_switcher.dart';
import 'package:flutter/material.dart';

class CurrencyForm extends StatefulWidget {
  const CurrencyForm({super.key});

  @override
  State<CurrencyForm> createState() => _CurrencyFormState();
}

class _CurrencyFormState extends State<CurrencyForm> {
  final PreferencesService _preferencesService = PreferencesService();
  late String _currentCurrency;
  late List<String> _reversedCurrencies;

  @override
  void initState() {
    super.initState();
    PreferencesService.init();
    _currentCurrency = _preferencesService.currency;
    _reversedCurrencies = List.from(
      PreferencesService.supportedCurrencies.reversed,
    );
    _preferencesService.addListener(_handlePreferencesChanged);
  }

  @override
  void dispose() {
    _preferencesService.removeListener(_handlePreferencesChanged);
    super.dispose();
  }

  void _handlePreferencesChanged() {
    if (mounted && _currentCurrency != _preferencesService.currency) {
      setState(() {
        _currentCurrency = _preferencesService.currency;
      });
    }
  }

  IconData _getCurrencyIcon(String currency) {
    switch (currency) {
      case 'USD':
        return Icons.attach_money_rounded;
      case 'GBP':
        return Icons.currency_pound_rounded;
      case 'EUR':
      default:
        return Icons.euro_symbol_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr.currency,
            style: theme.textTheme.headlineSmall!.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                shape: BoxShape.rectangle,
                color: theme.colorScheme.surfaceContainer,
              ),
              child: TabSwitcher(
                backgroundColor: theme.colorScheme.surfaceContainer,
                selectedIndex: _reversedCurrencies.indexOf(_currentCurrency),
                onTabSelected:
                    (index) => _preferencesService.setCurrency(
                      _reversedCurrencies[index],
                    ),
                tabs:
                    _reversedCurrencies
                        .map(
                          (currency) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              _getCurrencyIcon(currency),
                              size: 22,
                              color:
                                  currency == _currentCurrency
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
