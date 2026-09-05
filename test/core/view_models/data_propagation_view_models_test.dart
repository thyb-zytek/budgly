import 'package:budgly/src/pages/category_expenses/view_model.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/pages/settings/accounts/view_model.dart';
import 'package:budgly/src/pages/settings/categories/view_model.dart';
import 'package:budgly/src/pages/settings/preferences/view_model.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/stores/expenses.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';
import '../../helpers/fake_stores.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    clearAllTestStores();
    Fixtures.resetSeq();
  });

  tearDown(() {
    clearAllTestStores();
  });

  test('AccountsViewModel propagates account store mutations to listeners', () {
    final vm = AccountsViewModel();
    addTearDown(vm.dispose);
    var notifications = 0;
    vm.addListener(() => notifications++);

    final account = Fixtures.account(id: 'a1', name: 'Compte A');
    AccountsStore.instance.setAccounts([account]);
    expect(vm.accounts.single.name, 'Compte A');

    AccountsStore.instance.updateAccount(account.copyWith(name: 'Compte B'));
    expect(vm.accounts.single.name, 'Compte B');
    expect(notifications, greaterThanOrEqualTo(2));

    AccountsStore.instance.removeAccount('a1');
    expect(vm.accounts, isEmpty);
  });

  test('AccountsViewModel stops propagating after dispose', () {
    final vm = AccountsViewModel();
    var notifications = 0;
    vm.addListener(() => notifications++);
    vm.dispose();

    AccountsStore.instance.setAccounts([Fixtures.account(id: 'a1')]);
    expect(notifications, 0);
  });

  test('CategoriesViewModel propagates external create/update/delete', () {
    final account = Fixtures.account(id: 'a1');
    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    // Seed the store before assigning the account so the ViewModel does not
    // start an unrelated asynchronous remote/cache load during this focused
    // propagation test.
    CategoriesStore.instance.setCategoriesForAccount('a1', [category]);

    final vm = CategoriesViewModel();
    addTearDown(vm.dispose);
    vm.account = account;

    var notifications = 0;
    vm.addListener(() => notifications++);
    expect(vm.categories.single.name, 'Courses');

    CategoriesStore.instance.updateCategory(category.copyWith(name: 'Alimentation'));
    expect(vm.categories.single.name, 'Alimentation');

    CategoriesStore.instance.removeCategory('c1');
    expect(vm.categories, isEmpty);
    expect(notifications, greaterThanOrEqualTo(2));
  });

  test('PreferencesViewModel reflects external profile preference mutations', () {
    final vm = PreferencesViewModel();
    addTearDown(vm.dispose);
    var notifications = 0;
    vm.addListener(() => notifications++);

    ProfileStore.instance.setPreferences(
      themeMode: ThemeMode.dark,
      locale: const Locale('en'),
      currency: 'USD',
      amountDecimalPlaces: 0,
    );

    expect(vm.mode, ThemeMode.dark);
    expect(vm.locale.languageCode, 'en');
    expect(vm.currency, 'USD');
    expect(vm.amountDecimalPlaces, 0);
    expect(notifications, greaterThanOrEqualTo(1));
  });

  test('OverviewViewModel observes external account and expense mutations', () async {
    final vm = OverviewViewModel();
    addTearDown(vm.dispose);
    var notifications = 0;
    vm.addListener(() => notifications++);

    final account = Fixtures.account(id: 'a1');
    AccountsStore.instance.setAccounts([account]);
    await Future<void>.delayed(Duration.zero);
    expect(vm.accounts.single.id, 'a1');

    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    CategoriesStore.instance.setCategoriesForAccount('a1', [category]);
    final expense = Fixtures.expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      amount: 100,
    );
    ExpensesStore.instance.setExpensesForAccount('a1', [expense]);
    await Future<void>.delayed(Duration.zero);
    expect(notifications, greaterThanOrEqualTo(1));
  });

  test('CategoryExpensesViewModel observes external expense mutations', () async {
    final vm = CategoryExpensesViewModel(
      accountId: 'a1',
      categoryId: 'c1',
      period: Fixtures.period(2026, 3),
    );
    addTearDown(vm.dispose);
    var notifications = 0;
    vm.addListener(() => notifications++);

    ExpensesStore.instance.setExpensesForAccount('a1', [
      Fixtures.expense(
        id: 'e1',
        accountId: 'a1',
        categoryId: 'c1',
        amount: 100,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(notifications, greaterThanOrEqualTo(1));
  });

  test('shared store update is visible to multiple consumers without reload', () async {
    final account = Fixtures.account(id: 'a1');
    AccountsStore.instance.setAccounts([account]);
    CategoriesStore.instance.setCategoriesForAccount('a1', [
      Fixtures.category(id: 'c1', accountId: 'a1'),
      Fixtures.category(id: 'c2', accountId: 'a1', name: 'Transport'),
    ]);
    ExpensesStore.instance.setExpensesForAccount('a1', [
      Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 100),
    ]);

    final overview = OverviewViewModel();
    final categories = CategoriesViewModel()..account = account;
    addTearDown(overview.dispose);
    addTearDown(categories.dispose);

    var overviewNotifications = 0;
    overview.addListener(() => overviewNotifications++);
    ExpensesStore.instance.updateExpense(
      Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c2', amount: 250),
    );
    await Future<void>.delayed(Duration.zero);
    expect(overviewNotifications, greaterThanOrEqualTo(1));
    expect(categories.categories.length, 2);
    expect(ExpensesStore.instance.getExpenseById('e1')?.amount, 250);
    expect(ExpensesStore.instance.getExpenseById('e1')?.categoryId, 'c2');
  });


}
