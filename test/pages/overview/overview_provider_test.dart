import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/overview/account_selection_provider.dart';
import 'package:budgly/src/pages/overview/overview_provider.dart';
import 'package:budgly/src/pages/overview/period_expenses_provider.dart';
import 'package:budgly/src/pages/overview/revenue_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';

SyncManager _syncManager() =>
    SyncManager(queue: SyncQueue(), analytics: AnalyticsService());

class _FakeAccountsService extends AccountsService {
  _FakeAccountsService(this.values)
    : super(
        analytics: AnalyticsService(),
        syncManager: _syncManager(),
        syncQueue: SyncQueue(),
      );
  final List<Account> values;
  int loadCalls = 0;
  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async {
    loadCalls++;
    return values;
  }
}

class _EmptyCategoriesService extends CategoriesService {
  _EmptyCategoriesService()
    : super(
        analytics: AnalyticsService(),
        syncManager: _syncManager(),
        syncQueue: SyncQueue(),
      );
  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
    void Function(List<Category>)? onRevalidated,
  }) async => const [];
}

/// Also covers the calls `UndebitedExpensesProvider` makes through the same
/// `expensesServiceProvider` override, so `Overview.loadInitialData` can run
/// without ever reaching a real Firestore client.
class _FakeExpensesService extends ExpensesService {
  _FakeExpensesService(this.periodExpenses)
    : super(analytics: AnalyticsService());

  final List<Expense> periodExpenses;
  final List<String> periodLoadAccountIds = [];
  Expense? created;

  @override
  Future<List<Expense>> listExpensesForPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    bool forceRefresh = false,
    void Function(List<Expense>)? onRevalidated,
  }) async {
    periodLoadAccountIds.add(accountId);
    return periodExpenses;
  }

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async => periodExpenses;

  @override
  Future<List<Expense>> listExpensesForAccountBefore(
    String accountId,
    DateTime endExclusive, {
    bool forceRefresh = false,
  }) async => const [];

  @override
  Future<Expense> createExpense(Expense expense) async {
    created = expense.id == null ? expense.copyWith(id: 'created-1') : expense;
    return created!;
  }
}

class _FakeAccountBudgetsService extends AccountBudgetsService {
  _FakeAccountBudgetsService([this.value])
    : super(analytics: AnalyticsService());
  final AccountBudget? value;

  @override
  Future<AccountBudget?> loadRevenue(
    String accountId,
    int year,
    int month, {
    bool forceRefresh = false,
    void Function(AccountBudget?)? onRevalidated,
  }) async => value;

  @override
  Future<double?> getMostRecentRevenue(
    String accountId, {
    required Period before,
  }) async => null;
}

const _defaultProfile = ProfileSessionState(
  currentUser: null,
  hasLoaded: true,
  themeMode: ThemeMode.system,
  locale: Locale('fr'),
  currency: 'EUR',
  amountDecimalPlaces: 2,
);

ProviderContainer _fullContainer({
  required List<Account> accounts,
  List<Expense> expenses = const [],
  AccountBudget? budget,
}) => ProviderContainer(
  overrides: [
    accountsServiceProvider.overrideWithValue(_FakeAccountsService(accounts)),
    categoriesServiceProvider.overrideWithValue(_EmptyCategoriesService()),
    expensesServiceProvider.overrideWithValue(_FakeExpensesService(expenses)),
    accountBudgetsServiceProvider.overrideWithValue(
      _FakeAccountBudgetsService(budget),
    ),
    accountsSessionProvider.overrideWithValue(
      AccountsSessionState(
        accounts: List.unmodifiable(accounts),
        hasLoaded: true,
      ),
    ),
    categoriesSessionProvider.overrideWithValue(
      CategoriesSessionState(
        categoriesByAccount: {
          for (final account in accounts)
            if (account.id != null) account.id!: const [],
        },
        availableIcons: const [],
        iconsLoaded: false,
        loadedAccounts: accounts.map((a) => a.id).whereType<String>().toSet(),
      ),
    ),
    profileSessionProvider.overrideWithValue(_defaultProfile),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('account selection is owned by AccountSelection', () {
    final account = Fixtures.account(id: 'a1');
    final container = ProviderContainer(
      overrides: [
        accountsSessionProvider.overrideWithValue(
          AccountsSessionState(accounts: [account], hasLoaded: true),
        ),
        profileSessionProvider.overrideWithValue(
          const ProfileSessionState(
            currentUser: null,
            hasLoaded: true,
            themeMode: ThemeMode.system,
            locale: Locale('fr'),
            currency: 'EUR',
            amountDecimalPlaces: 2,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final selection = container.read(accountSelectionProvider.notifier);
    expect(container.read(accountSelectionProvider).selectedAccount?.id, 'a1');
    selection.select(null);
    expect(container.read(accountSelectionProvider).selectedAccount, isNull);
    selection.select(account);
    expect(container.read(accountSelectionProvider).selectedAccount?.id, 'a1');
  });

  test('overview owns only period and action status', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(overviewProvider.notifier);
    final next = Period.current().addMonths(1);
    notifier.selectPeriod(next);
    expect(container.read(overviewProvider).selectedPeriod, next);
  });

  test('loadInitialData populates period expenses and revenue for the selected '
      'account, and completes without error (RL-01 §3.2 happy path)', () async {
    final account = Fixtures.account(id: 'a1');
    final period = Period.current();
    final expense = Fixtures.expense(
      accountId: 'a1',
      categoryId: 'c1',
      debitDate: period.startOfMonth.add(const Duration(days: 2)),
    );
    final budget = Fixtures.budget(
      accountId: 'a1',
      period: period,
      revenue: 1500,
    );
    final container = _fullContainer(
      accounts: [account],
      expenses: [expense],
      budget: budget,
    );
    addTearDown(container.dispose);

    await container.read(overviewProvider.notifier).loadInitialData();

    final state = container.read(overviewProvider);
    expect(state.hasLoaded, isTrue);
    expect(state.status.isLoading, isFalse);
    expect(state.status.hasError, isFalse);
    expect(
      container
          .read(periodExpensesProvider('a1', period))
          .expenses
          .map((e) => e.id),
      [expense.id],
    );
    expect(container.read(revenueProvider('a1', period)).revenue, 1500);
  });

  test(
    'changing the selected account reloads period expenses for the new account',
    () async {
      final account1 = Fixtures.account(id: 'a1');
      final account2 = Fixtures.account(id: 'a2');
      final expensesService = _FakeExpensesService(const []);
      final container = ProviderContainer(
        overrides: [
          accountsSessionProvider.overrideWithValue(
            AccountsSessionState(
              accounts: [account1, account2],
              hasLoaded: true,
            ),
          ),
          categoriesSessionProvider.overrideWithValue(
            const CategoriesSessionState(
              categoriesByAccount: <String, List<Category>>{
                'a1': <Category>[],
                'a2': <Category>[],
              },
              availableIcons: [],
              iconsLoaded: false,
              loadedAccounts: {'a1', 'a2'},
            ),
          ),
          profileSessionProvider.overrideWithValue(_defaultProfile),
          expensesServiceProvider.overrideWithValue(expensesService),
          accountBudgetsServiceProvider.overrideWithValue(
            _FakeAccountBudgetsService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final overview = container.read(overviewProvider.notifier);
      overview.selectAccount(account2);
      await Future<void>.delayed(Duration.zero);

      expect(expensesService.periodLoadAccountIds, contains('a2'));
      expect(
        container.read(accountSelectionProvider).selectedAccount?.id,
        'a2',
      );
    },
  );

  test(
    'loadInitialData completes cleanly when the user has no accounts yet',
    () async {
      final container = _fullContainer(accounts: const []);
      addTearDown(container.dispose);

      await container.read(overviewProvider.notifier).loadInitialData();

      final state = container.read(overviewProvider);
      expect(state.hasLoaded, isTrue);
      expect(state.status.hasError, isFalse);
    },
  );

  test(
    'loadInitialData does not reload accounts: reference data is owned by the profile session',
    () async {
      final accountsService = _FakeAccountsService([
        Fixtures.account(id: 'a1'),
      ]);
      final account = Fixtures.account(id: 'a1');
      final container = ProviderContainer(
        overrides: [
          accountsServiceProvider.overrideWithValue(accountsService),
          categoriesServiceProvider.overrideWithValue(
            _EmptyCategoriesService(),
          ),
          expensesServiceProvider.overrideWithValue(
            _FakeExpensesService(const []),
          ),
          accountBudgetsServiceProvider.overrideWithValue(
            _FakeAccountBudgetsService(),
          ),
          accountsSessionProvider.overrideWithValue(
            AccountsSessionState(accounts: [account], hasLoaded: true),
          ),
          categoriesSessionProvider.overrideWithValue(
            const CategoriesSessionState(
              categoriesByAccount: {'a1': []},
              availableIcons: [],
              iconsLoaded: false,
              loadedAccounts: {'a1'},
            ),
          ),
          profileSessionProvider.overrideWithValue(_defaultProfile),
        ],
      );
      addTearDown(container.dispose);

      await container.read(overviewProvider.notifier).loadInitialData();

      expect(accountsService.loadCalls, 0);
      expect(container.read(overviewProvider).hasLoaded, isTrue);
      expect(container.read(overviewProvider).status.isLoading, isFalse);
    },
  );

  group('createExpense', () {
    test(
      'fails fast without touching any service when the account is missing',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final ok = await container
            .read(overviewProvider.notifier)
            .createExpense(
              form: ExpenseCreationFormData(
                name: 'Loyer',
                amount: '10',
                account: null,
                category: Fixtures.category(id: 'c1', accountId: 'a1'),
                debitDate: DateTime(2026, 3, 1),
                endDate: null,
                recurrence: RecurrenceType.none,
              ),
            );
        expect(ok, isFalse);
      },
    );

    test('fails fast when the category is missing', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ok = await container
          .read(overviewProvider.notifier)
          .createExpense(
            form: ExpenseCreationFormData(
              name: 'Loyer',
              amount: '10',
              account: Fixtures.account(id: 'a1'),
              category: null,
              debitDate: DateTime(2026, 3, 1),
              endDate: null,
              recurrence: RecurrenceType.none,
            ),
          );
      expect(ok, isFalse);
    });

    test('fails fast when the amount cannot be parsed', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ok = await container
          .read(overviewProvider.notifier)
          .createExpense(
            form: ExpenseCreationFormData(
              name: 'Loyer',
              amount: 'not-a-number',
              account: Fixtures.account(id: 'a1'),
              category: Fixtures.category(id: 'c1', accountId: 'a1'),
              debitDate: DateTime(2026, 3, 1),
              endDate: null,
              recurrence: RecurrenceType.none,
            ),
          );
      expect(ok, isFalse);
    });

    test('succeeds and reports a success message on valid input', () async {
      final expensesService = _FakeExpensesService(const []);
      final container = ProviderContainer(
        overrides: [expensesServiceProvider.overrideWithValue(expensesService)],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(overviewProvider.notifier)
          .createExpense(
            form: ExpenseCreationFormData(
              name: '  Loyer  ',
              amount: '800',
              account: Fixtures.account(id: 'a1'),
              category: Fixtures.category(id: 'c1', accountId: 'a1'),
              debitDate: DateTime(2026, 3, 1),
              endDate: null,
              recurrence: RecurrenceType.none,
            ),
          );

      expect(ok, isTrue);
      expect(expensesService.created?.name, 'Loyer');
      expect(container.read(overviewProvider).status.pendingMessage, isNotNull);
    });
  });

  test('consumeMessage clears the pending one-shot message', () async {
    final expensesService = _FakeExpensesService(const []);
    final container = ProviderContainer(
      overrides: [expensesServiceProvider.overrideWithValue(expensesService)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(overviewProvider.notifier);
    await notifier.createExpense(
      form: ExpenseCreationFormData(
        name: 'Loyer',
        amount: '800',
        account: Fixtures.account(id: 'a1'),
        category: Fixtures.category(id: 'c1', accountId: 'a1'),
        debitDate: DateTime(2026, 3, 1),
        endDate: null,
        recurrence: RecurrenceType.none,
      ),
    );
    expect(container.read(overviewProvider).status.pendingMessage, isNotNull);

    notifier.consumeMessage();

    expect(container.read(overviewProvider).status.pendingMessage, isNull);
  });
}
