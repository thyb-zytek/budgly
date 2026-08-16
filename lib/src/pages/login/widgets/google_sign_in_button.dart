import 'package:budgly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final void Function()? onPressed;

  const GoogleSignInButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    AppLocalizations tr = AppLocalizations.of(context)!;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: theme.colorScheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Image.asset(
            'assets/images/google.webp',
            height: 30,
          ),
          Expanded(
            child: Text(
              tr.googleSignIn,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium!.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}