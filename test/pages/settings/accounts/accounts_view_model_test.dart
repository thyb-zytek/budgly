import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/settings/accounts/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/builders.dart';
import '../../../helpers/fake_stores.dart';

class FakeAccountsService extends AccountsService {
  List<Account> values = [];
  bool loaded = true;
  int loadCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int deleteFolderCalls = 0;
  int getSignedUrlCalls = 0;
  Object? createError;
  Object? updateError;
  Object? deleteError;
  String? lastDeleteId;
  Account? created;
  Account? updated;
  int deleteByAccountCalls = 0;

  @override
  List<Account> get accounts => values;

  @override
  bool get hasLoaded => loaded;

  @override
  Listenable get changeNotifier => AccountsStoreHack.instance;

  @override
  Future<void> loadAccounts({bool forceRefresh = false}) async {
    loadCalls++;
  }

  @override
  Future<Account> createAccount(Account account) async {
    createCalls++;
    if (createError != null) throw createError!;
    created = account;
    return account.copyWith(id: 'new-account');
  }

  @override
  Future<Account> updateAccount(Account account) async {
    updateCalls++;
    if (updateError != null) throw updateError!;
    updated = account;
    return account;
  }

  @override
  Future<bool> deleteAccount(String accountId) async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
    lastDeleteId = accountId;
    return true;
  }

  @override
  Future<void> deleteAccountFolder(String accountId) async {
    deleteFolderCalls++;
  }

  @override
  Future<bool> deletePicture(String path, String accountId) async => true;

  @override
  Future<String?> getSignedUrl(String path, String accountId) async {
    getSignedUrlCalls++;
    return null;
  }

  @override
  void updateLocalAccount(Account account) {}
}

/// Simple ChangeNotifier to satisfy AccountsService.changeNotifier without
/// depending on the real store.
class AccountsStoreHack extends ChangeNotifier {
  AccountsStoreHack._();
  static final AccountsStoreHack instance = AccountsStoreHack._();
}

class FakeExpensesServiceForAccounts extends ExpensesService {
  int deleteByAccountCalls = 0;

  @override
  Future<void> deleteByAccountId(String accountId) async {
    deleteByAccountCalls++;
  }
}

class FakeBudgetServiceForAccounts extends AccountBudgetsService {
  int deleteByAccountCalls = 0;

  @override
  Future<void> deleteByAccountId(String accountId) async {
    deleteByAccountCalls++;
  }
}

class FakeCategoriesServiceForAccounts extends CategoriesService {
  int invalidateCalls = 0;

  @override
  void invalidateAccountCache(String accountId) {
    invalidateCalls++;
  }
}

void main() {
  late FakeAccountsService accounts;
  late FakeExpensesServiceForAccounts expenses;
  late FakeBudgetServiceForAccounts budgets;
  late FakeCategoriesServiceForAccounts categories;

  setUp(() {
    clearAllTestStores();
    accounts = FakeAccountsService();
    expenses = FakeExpensesServiceForAccounts();
    budgets = FakeBudgetServiceForAccounts();
    categories = FakeCategoriesServiceForAccounts();
  });

  tearDown(clearAllTestStores);

  test('accounts getter concatenates service and local accounts', () {
    accounts.values = [Fixtures.account(id: 'a1')];
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);

    expect(vm.accounts.single.id, 'a1');
    expect(vm.hasAccountsLoaded, isTrue);
  });

  test('addAccount appends a local draft and sets editing data', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);

    await vm.addAccount();

    expect(vm.isCreatingAccount, isTrue);
    expect(vm.accounts.single.id, isNull);
    expect(vm.accounts.single.name, isEmpty);
  });

  test('addAccount is a no-op when a draft already exists', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);
    await vm.addAccount();

    await vm.addAccount();

    expect(vm.accounts, hasLength(1));
  });

  test('setting editingAccount populates the editing data', () {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);
    final account = Fixtures.account(id: 'a1', name: 'Compte');

    vm.editingAccount = account;

    expect(vm.editingAccount?.id, 'a1');
    expect(vm.editingData.nameController.text, 'Compte');
  });

  test('setting editingAccount to null clears the name', () {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);
    vm.editingAccount = Fixtures.account(id: 'a1', name: 'Compte');

    vm.editingAccount = null;

    expect(vm.editingData.nameController.text, isEmpty);
  });

  test('cancelEdit clears editing account and name', () {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);
    vm.editingAccount = Fixtures.account(id: 'a1', name: 'Compte');

    vm.cancelEdit();

    expect(vm.editingAccount, isNull);
    expect(vm.editingData.nameController.text, isEmpty);
  });

  test('loadAccounts loads the accounts list', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);

    await vm.loadAccounts();

    expect(accounts.loadCalls, 1);
    expect(vm.viewState, ViewState.success);
  });

  test('removeAccount with null id removes the local draft only', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);
    await vm.addAccount();
    final draft = vm.accounts.single;

    await vm.removeAccount(draft);

    expect(vm.accounts, isEmpty);
    expect(accounts.deleteCalls, 0);
  });

  test('removeAccount deletes the account and cleans up related data', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);
    final account = Fixtures.account(id: 'a1');

    await vm.removeAccount(account);

    expect(accounts.deleteCalls, 1);
    expect(accounts.lastDeleteId, 'a1');
    expect(categories.invalidateCalls, 1);
    expect(expenses.deleteByAccountCalls, 1);
    expect(budgets.deleteByAccountCalls, 1);
    expect(vm.pendingUserMessage, isNotNull);
    expect(vm.viewState, ViewState.success);
  });

  test('removeAccount reports an error when deletion fails', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    accounts.deleteError = Exception('boom');
    addTearDown(vm.dispose);
    final account = Fixtures.account(id: 'a1');

    await vm.removeAccount(account);

    expect(vm.hasError, isTrue);
  });

  test('createAccount creates the account with the entered name and color', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);
    await vm.addAccount();
    final draft = vm.accounts.single;
    vm.editingData.nameController.text = 'Nouveau compte';
    vm.editingData.color = const Color(0xFF123456);

    await vm.createAccount(draft);

    expect(accounts.createCalls, 1);
    expect(accounts.created?.name, 'Nouveau compte');
    expect(accounts.created?.color, const Color(0xFF123456));
    expect(vm.pendingUserMessage, isNotNull);
    expect(vm.isCreatingAccount, isFalse);
  });

  test('createAccount reports an error when creation fails', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    accounts.createError = Exception('boom');
    addTearDown(vm.dispose);
    await vm.addAccount();
    final draft = vm.accounts.single;
    vm.editingData.nameController.text = 'Compte';

    await vm.createAccount(draft);

    expect(vm.hasError, isTrue);
  });

  test('updateAccount updates the account with the entered name', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);
    final account = Fixtures.account(id: 'a1', name: 'Avant');
    vm.editingAccount = account;
    vm.editingData.nameController.text = 'Après';

    await vm.updateAccount(account);

    expect(accounts.updateCalls, 1);
    expect(accounts.updated?.name, 'Après');
    expect(vm.pendingUserMessage, isNotNull);
    expect(vm.editingAccount, isNull);
  });

  test('updateAccount reports an error when updating fails', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    accounts.updateError = Exception('boom');
    addTearDown(vm.dispose);
    final account = Fixtures.account(id: 'a1');

    await vm.updateAccount(account);

    expect(vm.hasError, isTrue);
  });

  test('refreshPictureUrl refreshes a signed URL when the account has a picture', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);
    final account = Fixtures.account(id: 'a1', picture: 'pic.jpg');

    await vm.refreshPictureUrl(account);

    expect(accounts.getSignedUrlCalls, 1);
  });

  test('refreshPictureUrl is a no-op without id or picture', () async {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );

    await vm.refreshPictureUrl(Fixtures.account(id: 'a1'));

    expect(accounts.getSignedUrlCalls, 0);
  });

  test('view state is idle by default', () {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    addTearDown(vm.dispose);

    expect(vm.viewState, ViewState.idle);
  });

  test('dispose no longer reacts to service changes', () {
    final vm = AccountsViewModel(
      accountsService: accounts,
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );
    var count = 0;
    vm.addListener(() => count++);
    vm.dispose();

    AccountsStoreHack.instance.notifyListeners();

    expect(count, 0);
  });
}
