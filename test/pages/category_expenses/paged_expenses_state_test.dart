import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/pages/category_expenses/paged_expenses_state.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense(String id, DateTime date) => Expense(
      id: id,
      accountId: 'account',
      categoryId: 'category',
      name: id,
      amount: 10,
      debitDate: date,
    );

void main() {
  test('append deduplicates and keeps newest first', () {
    final state = PagedExpensesState();
    state.append([
      _expense('old', DateTime(2026, 1, 1)),
      _expense('new', DateTime(2026, 1, 10)),
    ]);
    state.append([_expense('new', DateTime(2026, 1, 10))]);

    expect(state.expenses.map((e) => e.id), ['new', 'old']);
  });

  test('replace and remove update the list by id', () {
    final state = PagedExpensesState()..append([
      _expense('a', DateTime(2026, 1, 1)),
      _expense('b', DateTime(2026, 1, 2)),
    ]);
    state.replace('a', _expense('a', DateTime(2026, 1, 5)));
    expect(state.expenses.first.id, 'a');
    state.removeById('a');
    expect(state.expenses.map((e) => e.id), ['b']);
  });
}
