import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/shared/ui/widgets/layout/preference_section.dart';
import 'package:budgly/src/shared/ui/widgets/selector.dart';
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

    return PreferenceSection(
      title: tr.locale,
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
    );
  }
}
