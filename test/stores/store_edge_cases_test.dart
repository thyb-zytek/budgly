import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/stores/expenses.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountsStore edge cases', () {
    late AccountsStore store;

    setUp(() {
      store = AccountsStore.instance;
      store.clearLocalAccounts();
    });

    Account account(String id, String name) => Account(id: id, userId: 'u1', name: name);

    test('setAccounts sorts by name without mutating the input list', () {
      final input = [account('a2', 'Zeta'), account('a1', 'Alpha')];
      store.setAccounts(input);

      expect(store.accounts.map((a) => a.id), ['a1', 'a2']);
      expect(input.map((a) => a.id), ['a2', 'a1']);
    });

    test('accounts getter is unmodifiable', () {
      store.setAccounts([account('a1', 'Main')]);
      expect(() => store.accounts.add(account('a2', 'Savings')), throwsUnsupportedError);
    });

    test('updateAccount is a no-op for an unknown id', () {
      store.setAccounts([account('a1', 'Main')]);
      var notifications = 0;
      store.addListener(() => notifications++);

      store.updateAccount(account('missing', 'Other'));

      expect(store.accounts.map((a) => a.id), ['a1']);
      expect(notifications, 0);
    });
  });

  group('CategoriesStore edge cases', () {
    late CategoriesStore store;

    setUp(() {
      store = CategoriesStore.instance;
      store.clearAll();
    });

    Category category(String id, String accountId) =>
        Category(id: id, name: id, accountId: accountId);

    test('categoriesByAccount is unmodifiable at the map boundary', () {
      store.setCategoriesForAccount('a1', [category('c1', 'a1')]);
      expect(() => store.categoriesByAccount.clear(), throwsUnsupportedError);
    });

    test('clearAccountCache is a no-op when nothing exists', () {
      var notifications = 0;
      store.addListener(() => notifications++);

      store.clearAccountCache('missing');

      expect(notifications, 0);
    });

    test('clearAll is a no-op on an already empty store', () {
      var notifications = 0;
      store.addListener(() => notifications++);

      store.clearAll();

      expect(notifications, 0);
    });
  });

  group('ExpensesStore edge cases', () {
    late ExpensesStore store;

    setUp(() {
      store = ExpensesStore.instance;
      store.clearAll();
    });

    Expense expense(String id, {String accountId = 'a1', String categoryId = 'c1'}) => Expense(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      name: id,
      amount: 10,
      debitDate: DateTime(2026, 8, 15),
    );

    test('getExpensesForAccount returns an unmodifiable list', () {
      store.addExpense(expense('e1'));
      expect(() => store.getExpensesForAccount('a1').clear(), throwsUnsupportedError);
    });

    test('updateExpense is a no-op for an unknown id', () {
      store.addExpense(expense('e1'));
      var notifications = 0;
      store.addListener(() => notifications++);

      store.updateExpense(expense('missing'));

      expect(store.getExpenseById('missing'), isNull);
      expect(notifications, 0);
    });

    test('removeExpense is a no-op for an unknown id', () {
      store.addExpense(expense('e1'));
      var notifications = 0;
      store.addListener(() => notifications++);

      store.removeExpense('missing', 'a1');

      expect(store.getExpensesForAccount('a1'), hasLength(1));
      expect(notifications, 0);
    });
  });
}
