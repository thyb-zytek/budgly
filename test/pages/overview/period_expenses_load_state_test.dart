import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/pages/overview/period_expenses_load_state.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense() => Expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      name: 'Coffee',
      amount: 5,
      debitDate: DateTime(2026, 8, 15),
    );

void main() {
  test('deduplicates concurrent loads for the same key', () async {
    final state = PeriodExpensesLoadState();
    var calls = 0;

    Future<List<Expense>> loader() async {
      calls++;
      await Future<void>.delayed(Duration.zero);
      return [_expense()];
    }

    final first = state.load('a1_2026_8', loader);
    final second = state.load('a1_2026_8', loader);

    expect(await first, hasLength(1));
    expect(await second, hasLength(1));
    expect(calls, 1);
    expect(state.loadingKey, isNull);
  });

  test('keeps different keys independent', () async {
    final state = PeriodExpensesLoadState();
    final first = await state.load('a1_2026_8', () async => [_expense()]);
    final second = await state.load('a1_2026_9', () async => const []);

    expect(first, hasLength(1));
    expect(second, isEmpty);
  });

  test('tracks loaded key separately from loading', () {
    final state = PeriodExpensesLoadState();

    expect(state.isLoaded('a1_2026_8'), isFalse);
    state.markLoaded('a1_2026_8');
    expect(state.isLoaded('a1_2026_8'), isTrue);
    state.invalidate();
    expect(state.isLoaded('a1_2026_8'), isFalse);
  });
}
