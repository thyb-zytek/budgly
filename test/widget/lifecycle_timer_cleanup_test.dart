import 'package:budgly/src/pages/login/widgets/verify_email.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('VerifyEmail cancels its periodic reload timer on dispose', (tester) async {
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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 31));

    expect(reloads, 0);
  });
}
