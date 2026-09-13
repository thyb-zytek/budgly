import 'package:budgly/src/stores/expenses.dart';
import 'package:budgly/src/stores/expenses_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';
import '../helpers/fake_stores.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    clearAllTestStores();
    Fixtures.resetSeq();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(clearAllTestStores);

  test('initial state mirrors ExpensesStore', () {
    final state = container.read(expensesSessionProvider);
    expect(state.expensesByAccount, isEmpty);
    expect(state.loadedAccounts, isEmpty);
  });

  test('reflects setExpensesForAccount made outside Riverpod', () {
    container.read(expensesSessionProvider);

    var notifications = 0;
    container.listen(expensesSessionProvider, (previous, next) => notifications++);

    ExpensesStore.instance.setExpensesForAccount('a1', [
      Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1'),
    ]);

    final state = container.read(expensesSessionProvider);
    expect(state.expensesByAccount['a1']!.single.id, 'e1');
    expect(state.loadedAccounts, contains('a1'));
    expect(notifications, greaterThanOrEqualTo(1));
  });

  test('reflects addExpense / updateExpense / removeExpense', () {
    container.read(expensesSessionProvider);
    ExpensesStore.instance.setExpensesForAccount('a1', [
      Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 10),
    ]);

    ExpensesStore.instance.addExpense(
      Fixtures.expense(id: 'e2', accountId: 'a1', categoryId: 'c1', amount: 20),
    );
    expect(container.read(expensesSessionProvider).expensesByAccount['a1']!.length, 2);

    ExpensesStore.instance.updateExpense(
      Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 99),
    );
    expect(
      container
          .read(expensesSessionProvider)
          .expensesByAccount['a1']!
          .firstWhere((e) => e.id == 'e1')
          .amount,
      99,
    );

    ExpensesStore.instance.removeExpense('e2', 'a1');
    expect(container.read(expensesSessionProvider).expensesByAccount['a1']!.length, 1);
  });

  test('an unrelated account is unaffected by another account changing', () {
    container.read(expensesSessionProvider);
    ExpensesStore.instance.setExpensesForAccount('a1', [
      Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1'),
    ]);
    ExpensesStore.instance.setExpensesForAccount('a2', [
      Fixtures.expense(id: 'e2', accountId: 'a2', categoryId: 'c2'),
    ]);

    final before = container.read(
      expensesSessionProvider.select((s) => s.expensesByAccount['a1']),
    );

    ExpensesStore.instance.addExpense(
      Fixtures.expense(id: 'e3', accountId: 'a2', categoryId: 'c2'),
    );

    final after = container.read(
      expensesSessionProvider.select((s) => s.expensesByAccount['a1']),
    );
    expect(identical(before, after), isTrue);
  });

  test('disposing the container detaches the store listener without error', () {
    final localContainer = ProviderContainer();
    localContainer.read(expensesSessionProvider);
    localContainer.dispose();

    expect(
      () => ExpensesStore.instance.setExpensesForAccount('a1', []),
      returnsNormally,
    );
  });
}
