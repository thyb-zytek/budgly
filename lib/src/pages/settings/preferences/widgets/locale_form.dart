import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/shared/widgets/selector/selector.dart';
import 'package:flutter/material.dart';

class LocaleForm extends StatelessWidget {
  final Locale currentLocale;
  final ValueChanged<Locale> onLocaleChanged;

  const LocaleForm({
    super.key,
    required this.currentLocale,
    required this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr.locale,
            style: theme.textTheme.headlineSmall!.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.3,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                shape: BoxShape.rectangle,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Selector<Locale>(
                  items: const [Locale('en'), Locale('fr')],
                  selectedItem: currentLocale,
                  onSelect: onLocaleChanged,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  itemBuilder: (context, locale) =>
                      Text(locale.languageCode.toUpperCase()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
