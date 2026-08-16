import 'package:budgly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class LoginAppbar extends StatelessWidget {
  final bool isCompact;

  const LoginAppbar({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    AppLocalizations tr = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: isCompact ? 10 : 40,
      children: [
        Row(
          spacing: 24,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: isCompact ? 100 : 125,
                child: Image.asset('assets/images/logo.png'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            tr.appDescription,
            style: theme.textTheme.titleLarge!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}