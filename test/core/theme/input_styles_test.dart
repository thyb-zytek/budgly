import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets('input types expose correct keyboard/autofill/password semantics', (tester) async {
    await pumpApp(tester, const SizedBox());
    expect(InputType.email.keyboardType, TextInputType.emailAddress);
    expect(InputType.password.obscuresText, isTrue);
    expect(InputType.password.autofillHints, contains(AutofillHints.password));
    expect(InputType.number.keyboardType.decimal, isTrue);
    expect(InputType.url.keyboardType, TextInputType.url);
  });

  testWidgets('currency validation accepts decimal comma/dot and rejects invalid input', (tester) async {
    await pumpApp(tester, Builder(builder: (context) {
      final tr = AppLocalizations.of(context)!;
      expect(InputType.currency.validateValue('12,50', tr), isNull);
      expect(InputType.currency.validateValue('-1.20', tr), isNull);
      expect(InputType.currency.validateValue('12 EUR', tr), tr.invalidCurrency);
      return const SizedBox();
    }));
  });

  testWidgets('decorate adds password toggle and clear action', (tester) async {
    var toggled = false;
    var cleared = false;
    await pumpApp(tester, Builder(builder: (context) {
      final decoration = InputType.password.decorate(
        const InputDecoration(),
        InputTypeContext(
          theme: Theme.of(context),
          obscureText: true,
          onToggleObscure: () => toggled = true,
          showClearButton: true,
          onClear: () => cleared = true,
        ),
      );
      return TextField(decoration: decoration);
    }));
    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.tap(find.byIcon(Icons.clear));
    expect(toggled, isTrue);
    expect(cleared, isTrue);
  });
}
