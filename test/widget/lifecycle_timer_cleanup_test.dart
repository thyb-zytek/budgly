import 'package:budgly/src/pages/login/widgets/verify_email.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('VerifyEmail cancels its periodic reload timer on dispose', (
    tester,
  ) async {
    var reloads = 0;

    await pumpApp(
      tester,
      VerifyEmail(
        email: 'test@example.com',
        onSignInPressed: () {},
        onResendPressed: () {},
        onReload: () => reloads++,
      ),
    );

    // The initial on-mount check is the only reload that may run.
    expect(reloads, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    // Several poll ticks (3 s each) would fire if the timer were not
    // cancelled on dispose.
    await tester.pump(const Duration(seconds: 6));

    expect(reloads, 1);
  });
}
