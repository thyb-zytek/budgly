import 'dart:async';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:flutter/material.dart';

class VerifyEmail extends StatefulWidget {
  const VerifyEmail({
    super.key,
    required this.email,
    required this.onSignInPressed,
    required this.onResendPressed,
    required this.onReload,
  });

  final String email;
  final VoidCallback onSignInPressed;
  final VoidCallback onResendPressed;
  final VoidCallback onReload;

  @override
  State<VerifyEmail> createState() => _VerifyEmailState();
}

class _VerifyEmailState extends State<VerifyEmail> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startReloadTimer();
  }

  void _startReloadTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      widget.onReload();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Text(
              tr.verifyEmailMessage(widget.email),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 24),
            child: FilledButton(
              style: ButtonType.primary.filledStyle(theme),
              onPressed: widget.onResendPressed,
              child: Text(
                tr.resendVerificationEmail,
                style: ButtonType.primary.labelStyle(theme),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: FilledButton(
              style: ButtonType.neutralVariant.filledStyle(theme),
              onPressed: widget.onSignInPressed,
              child: Text(
                tr.signIn,
                style: ButtonType.neutralVariant.labelStyle(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
