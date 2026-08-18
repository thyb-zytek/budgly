import 'package:budgly/l10n/app_localizations.dart';

class AuthValidators {
  static String? translateEmailError(AppLocalizations tr, String? code) {
    return switch (code) {
      'emailRequired' => tr.emailRequired,
      'emailInvalid' => tr.emailInvalid,
      _ => code,
    };
  }

  static String? translatePasswordError(AppLocalizations tr, String? code) {
    return switch (code) {
      'passwordRequired' => tr.passwordRequired,
      'passwordTooShort' => tr.passwordTooShort,
      _ => code,
    };
  }

  static String? translateConfirmPasswordError(AppLocalizations tr, String? code) {
    return switch (code) {
      'confirmPasswordRequired' => tr.passwordRequired,
      'passwordsDoNotMatch' => tr.passwordsDontMatch,
      _ => code,
    };
  }
}
