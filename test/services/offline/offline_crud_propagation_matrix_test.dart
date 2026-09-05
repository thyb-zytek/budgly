import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/stores/accounts_budget.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/stores/expenses.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';

void main() {
  setUp(() {
    AccountsStore.instance.clearLocalAccounts();
    CategoriesStore.instance.clearAll();
    AccountBudgetsStore.instance.clearAll();
    ExpensesStore.instance.clearAll();
  });

  group('offline local CRUD propagation contracts', () {
    test('account update is immediately visible to every consumer', () {
      final store = AccountsStore.instance;
      final account = Fixtures.account(id: 'a1', name: 'Courant');
      store.setAccounts([account]);

      final snapshots = <String>[];
      void listener() => snapshots.add(store.getAccountById('a1')?.name ?? 'missing');
      store.addListener(listener);
      addTearDown(() => store.removeListener(listener));

      store.updateAccount(account.copyWith(name: 'Courant modifié'));

      expect(store.getAccountById('a1')?.name, 'Courant modifié');
      expect(snapshots, ['Courant modifié']);
    });

    test('account delete removes the entity and notifies consumers', () {
      final store = AccountsStore.instance;
      store.setAccounts([
        Fixtures.account(id: 'a1', name: 'A'),
        Fixtures.account(id: 'a2', name: 'B'),
      ]);
      var notifications = 0;
      store.addListener(() => notifications++);

      store.removeAccount('a1');

      expect(store.getAccountById('a1'), isNull);
      expect(store.getAccountById('a2'), isNotNull);
      expect(notifications, 1);
    });

    test('category update propagates without replacing unrelated categories', () {
      final store = CategoriesStore.instance;
      final a = Fixtures.category(id: 'c1', accountId: 'a1', name: 'Courses');
      final b = Fixtures.category(id: 'c2', accountId: 'a1', name: 'Transport');
      store.setCategoriesForAccount('a1', [a, b]);

      store.updateCategory(a.copyWith(name: 'Alimentation'));

      expect(store.getCategoryById('c1')?.name, 'Alimentation');
      expect(store.getCategoryById('c2')?.name, 'Transport');
    });

    test('category delete removes only the requested category', () {
      final store = CategoriesStore.instance;
      store.setCategoriesForAccount('a1', [
        Fixtures.category(id: 'c1', accountId: 'a1'),
        Fixtures.category(id: 'c2', accountId: 'a1'),
      ]);

      store.removeCategory('c1');

      expect(store.getCategoryById('c1'), isNull);
      expect(store.getCategoryById('c2'), isNotNull);
    });

    test('budget update invalidates inherited-revenue consumers through store notification', () {
      final store = AccountBudgetsStore.instance;
      final budget = Fixtures.budget(
        accountId: 'a1',
        period: Fixtures.period(2026, 3),
        revenue: 2000,
      );
      store.set('a1_2026_3', budget);
      var notifications = 0;
      store.addListener(() => notifications++);

      store.set('a1_2026_3', budget.copyWith(revenue: 2400));

      expect(store.get('a1_2026_3')?.revenue, 2400);
      expect(notifications, 1);
    });

    test('expense update propagates to account consumers and preserves identity', () {
      final store = ExpensesStore.instance;
      final expense = Fixtures.expense(
        id: 'e1',
        accountId: 'a1',
        categoryId: 'c1',
        amount: 100,
      );
      store.addExpense(expense);
      var notifications = 0;
      store.addListener(() => notifications++);

      store.updateExpense(expense.copyWith(amount: 175));

      final current = store.getExpenseById('e1');
      expect(current?.id, 'e1');
      expect(current?.amount, 175);
      expect(store.getExpensesForAccount('a1'), hasLength(1));
      expect(notifications, 1);
    });

    test('expense move updates old and new account projections', () {
      final store = ExpensesStore.instance;
      final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1');
      store.setExpensesForAccount('a1', [expense]);
      store.setExpensesForAccount('a2', []);

      store.updateExpense(expense.copyWith(accountId: 'a2'));

      expect(store.getExpensesForAccount('a1'), isEmpty);
      expect(store.getExpensesForAccount('a2'), hasLength(1));
      expect(store.getExpenseById('e1')?.accountId, 'a2');
    });

    test('expense delete does not leak into another account', () {
      final store = ExpensesStore.instance;
      store.setExpensesForAccount('a1', [
        Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1'),
      ]);
      store.setExpensesForAccount('a2', [
        Fixtures.expense(id: 'e2', accountId: 'a2', categoryId: 'c2'),
      ]);

      store.removeExpense('e1', 'a1');

      expect(store.getExpenseById('e1'), isNull);
      expect(store.getExpenseById('e2'), isNotNull);
    });
  });

  group('listener fan-out', () {
    test('three independent screen consumers all observe the same expense mutation', () {
      final store = ExpensesStore.instance;
      final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 50);
      store.addExpense(expense);

      final observed = <double?>[];
      void overview() => observed.add(store.getExpenseById('e1')?.amount);
      void category() => observed.add(store.getExpenseById('e1')?.amount);
      void account() => observed.add(store.getExpenseById('e1')?.amount);
      store.addListener(overview);
      store.addListener(category);
      store.addListener(account);
      addTearDown(() {
        store.removeListener(overview);
        store.removeListener(category);
        store.removeListener(account);
      });

      store.updateExpense(expense.copyWith(amount: 90));

      expect(observed, [90, 90, 90]);
    });
  });
}
