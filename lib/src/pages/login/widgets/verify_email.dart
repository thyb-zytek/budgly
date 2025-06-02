import 'dart:async';

import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
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
            child: BudglyButton(
              text: tr.resendVerificationEmail,
              onPressed: widget.onResendPressed,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: BudglyButton(
              text: tr.signIn,
              type: ButtonType.neutralVariant,
              onPressed: widget.onSignInPressed,
            ),
          ),
        ],
      ),
    );
  }
}
