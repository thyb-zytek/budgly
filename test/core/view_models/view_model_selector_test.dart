import 'package:budgly/src/core/view_models/view_model_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Model extends ChangeNotifier {
  int value = 0;
  void setValue(int next) {
    value = next;
    notifyListeners();
  }
}

void main() {
  testWidgets('renders selected value and rebuilds when model changes', (tester) async {
    final model = _Model();
    await tester.pumpWidget(MaterialApp(
      home: ViewModelSelector<_Model, int>(
        model: model,
        selector: (m) => m.value,
        builder: (_, value) => Text('$value'),
      ),
    ));
    expect(find.text('0'), findsOneWidget);
    model.setValue(42);
    await tester.pump();
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('detaches from old model when widget model changes', (tester) async {
    final first = _Model()..value = 1;
    final second = _Model()..value = 2;
    await tester.pumpWidget(MaterialApp(
      home: ViewModelSelector<_Model, int>(
        model: first,
        selector: (m) => m.value,
        builder: (_, value) => Text('$value'),
      ),
    ));
    await tester.pumpWidget(MaterialApp(
      home: ViewModelSelector<_Model, int>(
        model: second,
        selector: (m) => m.value,
        builder: (_, value) => Text('$value'),
      ),
    ));
    first.setValue(99);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('99'), findsNothing);
  });
}
