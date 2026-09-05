import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/theme/material_theme.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('design tokens remain internally consistent', () {
    expect(BudglySpacing.xs, lessThan(BudglySpacing.sm));
    expect(BudglySpacing.sm, lessThan(BudglySpacing.md));
    expect(BudglySpacing.md, lessThan(BudglySpacing.lg));
    expect(BudglySpacing.lg, lessThan(BudglySpacing.xl));
    expect(BudglyRadius.medium, const BorderRadius.all(Radius.circular(12)));
    expect(BudglyComponentStyles.fabIconSize, lessThanOrEqualTo(BudglyComponentStyles.fabSize));
  });

  test('light and dark material schemes expose expected brightness', () {
    expect(MaterialTheme.lightScheme().brightness, Brightness.light);
    expect(MaterialTheme.darkScheme().brightness, Brightness.dark);
    expect(MaterialTheme.lightScheme().primary, isNot(MaterialTheme.darkScheme().primary));
  });

  test('material theme uses Material 3 and Budgly font', () {
    final theme = const MaterialTheme().theme(MaterialTheme.lightScheme());
    expect(theme.useMaterial3, isTrue);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Saira');
    expect(theme.colorScheme.brightness, Brightness.light);
  });

  testWidgets('button and snackbar styles resolve from the active theme', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: const MaterialTheme().theme(MaterialTheme.lightScheme()),
      home: Builder(builder: (context) {
        final success = ButtonType.success.colors(Theme.of(context));
        final error = ButtonType.error.colors(Theme.of(context));
        expect(success.background, isNotNull);
        expect(error.background, Theme.of(context).colorScheme.error);
        expect(SnackBarType.error.icon, Icons.error_outline_rounded);
        expect(SnackBarType.success.icon, Icons.check_circle_outline_rounded);
        return const SizedBox();
      }),
    ));
  });

  test('snackbar factory produces a floating snackbar', () {
    final snack = buildAppSnackBar('hello', SnackBarType.info);
    expect(snack.behavior, SnackBarBehavior.floating);
    expect(snack.duration, const Duration(seconds: 3));
  });
}
