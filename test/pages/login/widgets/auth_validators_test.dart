import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/login/widgets/auth_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('translates known auth validation codes', (tester) async {
    await pumpApp(tester, Builder(builder: (context) {
      final tr = AppLocalizations.of(context)!;
      expect(AuthValidators.translateEmailError(tr, 'emailRequired'), tr.emailRequired);
      expect(AuthValidators.translateEmailError(tr, 'emailInvalid'), tr.emailInvalid);
      expect(AuthValidators.translatePasswordError(tr, 'passwordRequired'), tr.passwordRequired);
      expect(AuthValidators.translatePasswordError(tr, 'passwordTooShort'), tr.passwordTooShort);
      expect(AuthValidators.translateConfirmPasswordError(tr, 'passwordsDoNotMatch'), tr.passwordsDontMatch);
      return const SizedBox();
    }));
  });

  testWidgets('unknown validation codes are preserved', (tester) async {
    await pumpApp(tester, Builder(builder: (context) {
      final tr = AppLocalizations.of(context)!;
      expect(AuthValidators.translateEmailError(tr, 'custom'), 'custom');
      expect(AuthValidators.translatePasswordError(tr, 'custom'), 'custom');
      expect(AuthValidators.translateConfirmPasswordError(tr, 'custom'), 'custom');
      expect(AuthValidators.translateEmailError(tr, null), isNull);
      return const SizedBox();
    }));
  });
}
