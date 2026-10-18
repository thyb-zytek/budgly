import 'dart:async';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
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
  final Future<bool> Function() onResendPressed;
  final VoidCallback onReload;

  @override
  State<VerifyEmail> createState() => _VerifyEmailState();
}

class _VerifyEmailState extends State<VerifyEmail> {
  /// Verification usually lands within a minute of the email being sent, so a
  /// short interval catches it quickly without hammering Firebase's
  /// `reload()` forever.
  static const _reloadInterval = Duration(seconds: 3);

  /// Number of checks issued before the polling window closes (~1 minute).
  static const _maxReloadAttempts = 20;

  Timer? _timer;
  int _reloadAttempts = 0;

  @override
  void initState() {
    super.initState();
    _startReloadTimer();
  }

  void _startReloadTimer() {
    // Restarting must not stack timers: the resend flow opens a fresh window.
    _timer?.cancel();
    _reloadAttempts = 0;
    _timer = Timer.periodic(_reloadInterval, (timer) {
      _reloadAttempts++;
      widget.onReload();
      if (_reloadAttempts >= _maxReloadAttempts) timer.cancel();
    });
  }

  Future<void> _handleResendPressed() async {
    final sent = await widget.onResendPressed();
    // Only restart the polling when the email was actually sent. A refused
    // resend (e.g. the cooldown guard) must leave the current cycle running.
    if (sent && mounted) _startReloadTimer();
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
            padding: EdgeInsets.only(top: BudglySpacing.xl),
            child: FilledButton(
              onPressed: _handleResendPressed,
              child: Text(tr.resendVerificationEmail),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: BudglySpacing.sm),
            child: FilledButton(
              style: ButtonType.neutralVariant.filledStyle(theme),
              onPressed: widget.onSignInPressed,
              child: Text(tr.signIn),
            ),
          ),
        ],
      ),
    );
  }
}
