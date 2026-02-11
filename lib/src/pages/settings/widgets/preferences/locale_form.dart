import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/inputs/dropdown.dart';
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
                maxWidth: MediaQuery.of(context).size.width * 0.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                shape: BoxShape.rectangle,
                color: theme.colorScheme.surfaceContainer,
              ),
              child: DropDown(
                dense: true,
                initialValue: currentLocale,
                options: AppLocalizations.supportedLocales,
                onSelect: onLocaleChanged,
                optionBuilder:
                    (option, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Text(option.languageCode.toUpperCase()),
                    ),
                ),
              ),  
            ),
        ],
      ),
    );
  }
}
