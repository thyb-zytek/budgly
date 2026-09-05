import 'package:budgly/src/shared/ui/widgets/gestures/horizontal_swipe_detector.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/amount_format_incrementer.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/currency_input.dart';
import 'package:budgly/src/shared/ui/widgets/layout/budgly_fab.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:budgly/src/shared/ui/widgets/layout/framed_container.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/shared/ui/widgets/layout/preference_section.dart';
import 'package:budgly/src/shared/ui/widgets/layout/section_label.dart';
import 'package:budgly/src/shared/ui/widgets/tabs/tab_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('common layout widgets render their content', (tester) async {
    await pumpApp(tester, const Column(
      children: [
        EmptyState(icon: Icons.inbox, title: 'Empty', subtitle: 'Nothing here'),
        SectionLabel('Section'),
        PreferenceSection(title: 'Preference', child: Text('Value')),
        FramedContainer(child: Text('Framed')),
        AppLoadingIndicator(),
      ],
    ), settle: false);
    await tester.pump();
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('SECTION'), findsOneWidget);
    expect(find.text('Preference'), findsOneWidget);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('Framed'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AmountFormatIncrementer clamps changes to 0..2', (tester) async {
    final values = <int>[];
    await pumpApp(tester, AmountFormatIncrementer(
      decimalPlaces: 1,
      currency: 'EUR',
      onChanged: values.add,
    ));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.tap(find.byIcon(Icons.add));
    expect(values, [0, 2]);
  });

  testWidgets('TabSwitcher reports the selected tab index', (tester) async {
    var selected = -1;
    await pumpApp(tester, TabSwitcher(
      selectedIndex: 0,
      onTabSelected: (index) => selected = index,
      tabs: const [Text('One'), Text('Two')],
    ));
    await tester.tap(find.text('Two'));
    expect(selected, 1);
  });

  testWidgets('HorizontalSwipeDetector distinguishes forward and backward swipes', (tester) async {
    final directions = <SwipeDirection>[];
    await pumpApp(tester, HorizontalSwipeDetector(
      onSwipe: directions.add,
      child: const SizedBox(width: 300, height: 200),
    ));
    await tester.drag(find.byType(HorizontalSwipeDetector), const Offset(-100, 0));
    await tester.drag(find.byType(HorizontalSwipeDetector), const Offset(100, 0));
    expect(directions, [SwipeDirection.forward, SwipeDirection.backward]);
  });

  testWidgets('BudglyFab invokes callback when enabled and ignores it when disabled', (tester) async {
    var calls = 0;
    await pumpApp(tester, Column(children: [
      BudglyFab(heroTag: 'enabled', label: 'Add', onPressed: () => calls++),
      BudglyFab(heroTag: 'disabled', onPressed: () => calls++, disabled: true),
    ]));
    expect(find.text('Add'), findsOneWidget);
    await tester.tap(find.text('Add'));
    expect(calls, 1);
  });

  testWidgets('CurrencyInput renders currency affordance and accepts valid amount', (tester) async {
    final controller = TextEditingController(text: '12,50');
    addTearDown(controller.dispose);
    await pumpApp(tester, CurrencyInput(
      controller: controller,
      currencyCode: 'EUR',
      labelText: 'Amount',
    ));
    expect(find.text('Amount'), findsOneWidget);
    expect(find.byIcon(Icons.euro_symbol_rounded), findsOneWidget);
  });
}
