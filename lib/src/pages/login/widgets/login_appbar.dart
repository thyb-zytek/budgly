import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class LoginAppbar extends StatelessWidget {
  const LoginAppbar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    AppLocalizations tr = AppLocalizations.of(context)!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 40,
      children: [
        Row(
          spacing: 24,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.max,
          children: [
            Image.asset('assets/images/logo.png', width: 135),
            Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                "Budgly",
                style: theme.textTheme.displayLarge!.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            tr.appDescription,
            style: theme.textTheme.headlineSmall!.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}
