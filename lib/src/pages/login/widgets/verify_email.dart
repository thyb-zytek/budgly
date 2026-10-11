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
  final VoidCallback onResendPressed;
  final VoidCallback onReload;

  @override
  State<VerifyEmail> createState() => _VerifyEmailState();
}

class _VerifyEmailState extends State<VerifyEmail> with WidgetsBindingObserver {
  /// Polling gives up after this many failed reloads so an unverified account
  /// cannot poll forever (battery/network) and Firebase Auth rate limits on
  /// `reload()` (getAccountInfo) stay respected: 10 ticks x 3 s = 30 s.
  static const _maxReloadAttempts = 10;
  static const _pollInterval = Duration(seconds: 3);

  Timer? _timer;
  int _reloadAttempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check straight away so an account verified elsewhere (or between the
    // sign-up and this screen) redirects immediately, without waiting for the
    // first poll tick.
    widget.onReload();
    _startReloadTimer();
  }

  void _startReloadTimer() {
    _timer?.cancel();
    _reloadAttempts = 0;
    _timer = Timer.periodic(_pollInterval, (timer) {
      if (_reloadAttempts >= _maxReloadAttempts) {
        timer.cancel();
        _timer = null;
        return;
      }
      _reloadAttempts++;
      widget.onReload();
    });
  }

  void _handleResendPressed() {
    // A freshly sent email deserves a fresh polling window: otherwise the
    // auto-redirect would silently stop once the previous budget is spent.
    _startReloadTimer();
    widget.onResendPressed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The verification link is opened in a browser or an in-app browser, so
    // by the time the user returns to the app the account is usually already
    // verified: reload at once instead of waiting for the next tick.
    if (state == AppLifecycleState.resumed) {
      widget.onReload();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
