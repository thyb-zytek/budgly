import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/settings/accounts/accounts_settings_provider.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/builders.dart';
import '../../../helpers.dart';

class FakeAccountsService extends AccountsService {
  FakeAccountsService()
    : super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );
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
  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async {
    loadCalls++;
    return values;
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
  Future<void> deleteAccountFolder(
    String accountId, {
    bool throwOnFailure = false,
  }) async {
    deleteFolderCalls++;
  }

  @override
  Future<bool> deletePicture(String path, String accountId) async => true;

  @override
  Future<String?> getSignedUrl(String path, String accountId) async {
    getSignedUrlCalls++;
    return null;
  }
}

class FakeExpensesServiceForAccounts extends ExpensesService {
  FakeExpensesServiceForAccounts() : super(analytics: AnalyticsService());
  int deleteByAccountCalls = 0;

  @override
  Future<void> deleteByAccountId(String accountId) async {
    deleteByAccountCalls++;
  }
}

class FakeBudgetServiceForAccounts extends AccountBudgetsService {
  FakeBudgetServiceForAccounts() : super(analytics: AnalyticsService());
  int deleteByAccountCalls = 0;

  @override
  Future<void> deleteByAccountId(String accountId) async {
    deleteByAccountCalls++;
  }
}

class FakeCategoriesServiceForAccounts extends CategoriesService {
  FakeCategoriesServiceForAccounts()
    : super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );
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
  late ProviderContainer container;

  setUp(() {
    accounts = FakeAccountsService();
    expenses = FakeExpensesServiceForAccounts();
    budgets = FakeBudgetServiceForAccounts();
    categories = FakeCategoriesServiceForAccounts();
    container = ProviderContainer(
      overrides: [
        accountsServiceProvider.overrideWithValue(accounts),
        expensesServiceProvider.overrideWithValue(expenses),
        accountBudgetsServiceProvider.overrideWithValue(budgets),
        categoriesServiceProvider.overrideWithValue(categories),
      ],
    );
    addTearDown(container.dispose);
    container.listen(accountsSettingsProvider, (_, _) {});
  });

  AccountsSettings notifier() =>
      container.read(accountsSettingsProvider.notifier);
  AccountsSettingsState state() => container.read(accountsSettingsProvider);

  test('initial state has no drafts and is idle', () {
    expect(state().localAccounts, isEmpty);
    expect(state().editingAccount, isNull);
    expect(state().status.isLoading, isFalse);
  });

  test('addAccount appends a local draft and returns it', () async {
    final draft = await notifier().addAccount();

    expect(draft, isNotNull);
    expect(state().isCreatingAccount, isTrue);
    expect(state().localAccounts.single.id, isNull);
    expect(state().localAccounts.single.name, isEmpty);
    expect(draft, same(state().localAccounts.single));
  });

  test('addAccount is a no-op when a draft already exists', () async {
    await notifier().addAccount();

    final second = await notifier().addAccount();

    expect(second, isNull);
    expect(state().localAccounts, hasLength(1));
  });

  test('setEditingAccount updates the state', () {
    final account = Fixtures.account(id: 'a1', name: 'Compte');

    notifier().setEditingAccount(account);

    expect(state().editingAccount?.id, 'a1');
  });

  test('cancelEdit clears the editing account', () {
    notifier().setEditingAccount(Fixtures.account(id: 'a1', name: 'Compte'));

    notifier().cancelEdit();

    expect(state().editingAccount, isNull);
  });

  test('loadAccounts loads the accounts list', () async {
    await notifier().loadAccounts();

    expect(accounts.loadCalls, 1);
    expect(state().status.isLoading, isFalse);
    expect(state().status.hasError, isFalse);
  });

  test('loadAccounts reports an error when loading fails', () async {
    final c = ProviderContainer(
      overrides: [
        accountsServiceProvider.overrideWithValue(
          _ThrowingLoadAccountsService(),
        ),
        expensesServiceProvider.overrideWithValue(expenses),
        accountBudgetsServiceProvider.overrideWithValue(budgets),
        categoriesServiceProvider.overrideWithValue(categories),
      ],
    );
    addTearDown(c.dispose);

    await c.read(accountsSettingsProvider.notifier).loadAccounts();

    expect(c.read(accountsSettingsProvider).status.hasError, isTrue);
  });

  test('removeAccount with null id removes the local draft only', () async {
    final draft = await notifier().addAccount();

    await notifier().removeAccount(draft!);

    expect(state().localAccounts, isEmpty);
    expect(accounts.deleteCalls, 0);
  });

  test(
    'removeAccount deletes the account and cleans up related data',
    () async {
      final account = Fixtures.account(id: 'a1');

      await notifier().removeAccount(account);
      // Cleanup is fired with `unawaited`; give it a tick to run.
      await Future<void>.delayed(Duration.zero);

      expect(accounts.deleteCalls, 1);
      expect(accounts.lastDeleteId, 'a1');
      expect(categories.invalidateCalls, 1);
      expect(expenses.deleteByAccountCalls, 1);
      expect(budgets.deleteByAccountCalls, 1);
      expect(state().status.pendingMessage, isNotNull);
      expect(state().status.hasError, isFalse);
    },
  );

  test('removeAccount reports an error when deletion fails', () async {
    accounts.deleteError = Exception('boom');
    final account = Fixtures.account(id: 'a1');

    await notifier().removeAccount(account);

    expect(state().status.hasError, isTrue);
  });

  test(
    'createAccount creates the account with the given name and color',
    () async {
      final draft = (await notifier().addAccount())!;

      await notifier().createAccount(
        draftAccount: draft,
        name: 'Nouveau compte',
        color: const Color(0xFF123456),
        picture: null,
        isLocalPicture: false,
      );

      expect(accounts.createCalls, 1);
      expect(accounts.created?.name, 'Nouveau compte');
      expect(accounts.created?.color, const Color(0xFF123456));
      expect(state().status.pendingMessage, isNotNull);
      expect(state().isCreatingAccount, isFalse);
      expect(state().editingAccount, isNull);
    },
  );

  test('createAccount reports an error when creation fails', () async {
    accounts.createError = Exception('boom');
    final draft = (await notifier().addAccount())!;

    await notifier().createAccount(
      draftAccount: draft,
      name: 'Compte',
      color: const Color(0xFF123456),
      picture: null,
      isLocalPicture: false,
    );

    expect(state().status.hasError, isTrue);
  });

  test('updateAccount updates the account with the given name', () async {
    final account = Fixtures.account(id: 'a1', name: 'Avant');
    notifier().setEditingAccount(account);

    await notifier().updateAccount(
      account: account,
      name: 'Après',
      color: const Color(0xFF123456),
      picture: null,
      isLocalPicture: false,
    );

    expect(accounts.updateCalls, 1);
    expect(accounts.updated?.name, 'Après');
    expect(state().status.pendingMessage, isNotNull);
    expect(state().editingAccount, isNull);
  });

  test('updateAccount reports an error when updating fails', () async {
    accounts.updateError = Exception('boom');
    final account = Fixtures.account(id: 'a1');

    await notifier().updateAccount(
      account: account,
      name: 'Après',
      color: const Color(0xFF123456),
      picture: null,
      isLocalPicture: false,
    );

    expect(state().status.hasError, isTrue);
  });

  test(
    'loadAccounts refreshes signed URLs for accounts with a picture',
    () async {
      accounts.values = [Fixtures.account(id: 'a1', picture: 'pic.jpg')];

      await notifier().loadAccounts();
      // getSignedUrl is refreshed via an unawaited Future.wait inside
      // loadAccounts — give it a tick to run.
      await Future<void>.delayed(Duration.zero);

      expect(accounts.getSignedUrlCalls, 1);
    },
  );

  test(
    'consumeMessage clears the pending message without touching the rest',
    () async {
      await notifier().removeAccount(Fixtures.account(id: 'a1'));
      expect(state().status.pendingMessage, isNotNull);

      notifier().consumeMessage();

      expect(state().status.pendingMessage, isNull);
    },
  );
}

class _ThrowingLoadAccountsService extends AccountsService {
  _ThrowingLoadAccountsService()
    : super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );
  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async {
    throw Exception('offline');
  }
}
