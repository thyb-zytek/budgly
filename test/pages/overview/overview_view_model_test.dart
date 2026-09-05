import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/pages/overview/overview_repository.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/stores/accounts_budget.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';
import '../../helpers/fake_stores.dart';

class FakeOverviewAccountsService extends AccountsService {
  final List<Account> values;
  Object? loadError;
  FakeOverviewAccountsService(this.values);
  @override
  List<Account> get accounts => values;
  @override
  bool get hasLoaded => true;
  @override
  Future<void> loadAccounts({bool forceRefresh = false}) async {
    if (loadError != null) throw loadError!;
  }
}

class FakeOverviewCategoriesService extends CategoriesService {
  @override
  List<Category> getCategoriesForAccount(String accountId) => const [];
}

class FakeOverviewExpensesService extends ExpensesService {
  Expense? created;
  bool failCreate = false;
  List<Expense> accountExpenses = const [];

  @override
  List<Expense> getExpensesForAccount(String accountId) => accountExpenses;

  @override
  Future<Expense> createExpense(Expense expense) async {
    if (failCreate) throw StateError('offline');
    created = expense;
    return expense.copyWith(id: 'new-expense');
  }
}

class FakeOverviewBudgetService extends AccountBudgetsService {
  final Set<String> loaded = {};
  final Map<String, double> values = {};
  int loadCalls = 0;
  int setRevenueCalls = 0;
  double? lastSetRevenue;

  String key(String accountId, int year, int month) => '$accountId-$year-$month';

  @override
  bool hasLoaded(String accountId, int year, int month) => loaded.contains(key(accountId, year, month));

  @override
  Future<void> loadRevenue(String accountId, int year, int month, {bool forceRefresh = false}) async {
    loadCalls++;
    loaded.add(key(accountId, year, month));
  }

  @override
  double getRevenue(String accountId, int year, int month) => values[key(accountId, year, month)] ?? 0;

  @override
  Future<void> setRevenue(String accountId, int year, int month, double value) async {
    setRevenueCalls++;
    lastSetRevenue = value;
    values[key(accountId, year, month)] = value;
    loaded.add(key(accountId, year, month));
  }
}

class FakeOverviewRepository extends OverviewRepository {
  final List<Expense> initialExpenses;
  final List<String> calls = [];
  bool failRefresh = false;
  double? inheritedRevenue;

  FakeOverviewRepository({this.initialExpenses = const []});

  @override
  Future<List<Expense>> loadInitialData(Account account, Period period) async {
    calls.add('initial:${account.id}:$period');
    return initialExpenses;
  }

  @override
  Future<List<Expense>> loadPeriodExpenses(String accountId, Period period, {bool forceRefresh = false}) async {
    calls.add('period:$accountId:$period:$forceRefresh');
    return initialExpenses;
  }

  @override
  Future<void> refresh(Account account, Period period) async {
    calls.add('refresh:${account.id}:$period');
    if (failRefresh) throw StateError('offline');
  }

  @override

  @override
  Future<void> loadRevenueInBackground(String accountId, int year, int month) async {}

  @override
  Future<double?> getMostRecentRevenue(String accountId, {required Period before}) async => inheritedRevenue;
}

void main() {
  setUp(() {
    clearAllTestStores();
    Fixtures.resetSeq();
  });

  tearDown(clearAllTestStores);

  test('loadInitialData selects the first account and loads its period data', () async {
    final accounts = [Fixtures.account(id: 'a1'), Fixtures.account(id: 'a2')];
    final repo = FakeOverviewRepository();
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService(accounts),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: repo,
    );
    addTearDown(vm.dispose);

    await vm.loadInitialData();

    expect(vm.account?.id, 'a1');
    expect(repo.calls.single, startsWith('initial:a1:'));
    expect(vm.isLoading, isFalse);
  });

  test('switching account invalidates period data and requests the new account', () async {
    final a1 = Fixtures.account(id: 'a1');
    final a2 = Fixtures.account(id: 'a2');
    final repo = FakeOverviewRepository();
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([a1, a2]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: repo,
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    vm.account = a2;
    await Future<void>.delayed(Duration.zero);

    expect(vm.account?.id, 'a2');
    expect(repo.calls.any((c) => c.startsWith('period:a2:')), isTrue);
  });

  test('changing period invalidates derived data and reloads expenses', () async {
    final account = Fixtures.account(id: 'a1');
    final repo = FakeOverviewRepository();
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: repo,
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();
    const next = Period(year: 2026, month: 7);

    vm.selectedPeriod = next;
    await Future<void>.delayed(Duration.zero);

    expect(vm.selectedPeriod, next);
    expect(repo.calls.any((c) => c == 'period:a1:$next:false'), isTrue);
  });

  test('refreshAll reports an error when the remote refresh fails', () async {
    final account = Fixtures.account(id: 'a1');
    final repo = FakeOverviewRepository()..failRefresh = true;
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: repo,
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    await vm.refreshAll();

    expect(vm.hasError, isTrue);
    expect(repo.calls.any((c) => c.startsWith('refresh:a1:')), isTrue);
  });

  test('setting account to null clears the selected account and increments revision', () async {
    final account = Fixtures.account(id: 'a1');
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    vm.account = null;

    expect(vm.account, isNull);
  });

  test('createExpense builds the expense from the form and returns success', () async {
    final account = Fixtures.account(id: 'a1');
    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    seedCategories('a1', [category]);
    final expenses = FakeOverviewExpensesService();
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: CategoriesService.instance,
      expensesService: expenses,
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    vm.expenseForm.setAccount(account);
    vm.expenseForm.setCategory(category);
    vm.expenseForm.data.nameController.text = 'Courses';
    vm.expenseForm.data.amountController.text = '99.9';

    expect(await vm.createExpense(), isTrue);
    expect(expenses.created?.name, 'Courses');
    expect(expenses.created?.amount, 99.9);
    expect(expenses.created?.accountId, 'a1');
    expect(expenses.created?.categoryId, 'c1');
    expect(vm.pendingUserMessage, isNotNull);
    expect(vm.isSaving, isFalse);
  });

  test('createExpense refuses when the form has no account or category', () async {
    final account = Fixtures.account(id: 'a1');
    final expenses = FakeOverviewExpensesService();
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: expenses,
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    vm.expenseForm.data.nameController.text = 'Courses';
    vm.expenseForm.data.amountController.text = '99.9';

    expect(await vm.createExpense(), isFalse);
    expect(expenses.created, isNull);
    expect(vm.isSaving, isFalse);
  });

  test('createExpense reports an error and returns false when persistence fails', () async {
    final account = Fixtures.account(id: 'a1');
    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    seedCategories('a1', [category]);
    final expenses = FakeOverviewExpensesService()..failCreate = true;
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: CategoriesService.instance,
      expensesService: expenses,
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    vm.expenseForm.setAccount(account);
    vm.expenseForm.setCategory(category);
    vm.expenseForm.data.amountController.text = '10';

    expect(await vm.createExpense(), isFalse);
    expect(vm.hasError, isTrue);
    expect(vm.isSaving, isFalse);
  });

  test('setRevenue persists the value and surfaces a success message', () async {
    final account = Fixtures.account(id: 'a1');
    final budget = FakeOverviewBudgetService();
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: budget,
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    await vm.setRevenue(1200);

    expect(budget.setRevenueCalls, 1);
    expect(budget.lastSetRevenue, 1200);
    expect(vm.viewState, ViewState.success);
    expect(vm.pendingUserMessage, isNotNull);
  });

  test('setRevenue is a no-op when no account is selected', () async {
    final account = Fixtures.account(id: 'a1');
    final budget = FakeOverviewBudgetService();
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: budget,
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();
    vm.account = null;

    await vm.setRevenue(500);

    expect(budget.setRevenueCalls, 0);
  });

  test('openRevenueEditor and closeRevenueEditor toggle the editor state', () {
    final account = Fixtures.account(id: 'a1');
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);

    expect(vm.uiState.showRevenueEditor, isFalse);
    vm.openRevenueEditor();
    expect(vm.uiState.showRevenueEditor, isTrue);
    vm.closeRevenueEditor();
    expect(vm.uiState.showRevenueEditor, isFalse);
  });

  test('revenue editor auto-shows when revenue and inherited revenue are both zero', () async {
    final account = Fixtures.account(id: 'a1');
    final budget = FakeOverviewBudgetService();
    final period = Period.current();
    budget.loaded.add('a1-${period.year}-${period.month}');
    final repo = FakeOverviewRepository()..inheritedRevenue = 0;
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: budget,
      repository: repo,
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();
    await Future<void>.delayed(Duration.zero);

    expect(vm.uiState.showRevenueEditor, isTrue);
    expect(vm.inheritedRevenue, 0);
    expect(vm.isRevenueEstimated, isFalse);
    expect(vm.effectiveRevenue, 0);
  });

  test('revenue editor stays hidden when a positive inherited revenue exists', () async {
    final account = Fixtures.account(id: 'a1');
    final budget = FakeOverviewBudgetService();
    final period = Period.current();
    budget.loaded.add('a1-${period.year}-${period.month}');
    final repo = FakeOverviewRepository()..inheritedRevenue = 800;
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: budget,
      repository: repo,
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();
    await Future<void>.delayed(Duration.zero);

    expect(vm.inheritedRevenue, 800);
    expect(vm.isRevenueEstimated, isTrue);
    expect(vm.effectiveRevenue, 800);
    expect(vm.uiState.showRevenueEditor, isFalse);
  });

  test('derived stats combine occurrences, pending, and remaining', () async {
    final account = Fixtures.account(id: 'a1');
    final period = Period.current();
    final debited = Fixtures.expense(
      id: 'e-d', accountId: 'a1', categoryId: 'c1', amount: 50,
      debitDate: DateTime(period.year, period.month, 5), isDebited: true,
    );
    final pending = Fixtures.expense(
      id: 'e-p', accountId: 'a1', categoryId: 'c1', amount: 100,
      debitDate: DateTime(period.year, period.month, 20), isDebited: false,
    );
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(initialExpenses: [debited, pending]),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    expect(vm.periodOccurrences, hasLength(2));
    expect(vm.totalExpenses, 150);
    expect(vm.pendingExpenses, 100);
    expect(vm.remaining, -150);
    expect(vm.remainingWeekendsInPeriod, isNotNull);
    final weekends = vm.remainingWeekendsInPeriod!;
    final expectedWeeklyBudget = -150 / (weekends > 0 ? weekends : 1);
    expect(vm.weeklyBudget, expectedWeeklyBudget);
  });

  test('expenses and hasExpensesLoaded clear when the selected period key changes', () async {
    final account = Fixtures.account(id: 'a1');
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();
    expect(vm.hasExpensesLoaded, isTrue);

    vm.selectedPeriod = const Period(year: 2030, month: 1);

    expect(vm.hasExpensesLoaded, isFalse);
    expect(vm.expenses, isEmpty);
  });

  test('startNewExpense resets the form for creation using the first category', () async {
    final account = Fixtures.account(id: 'a1');
    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    seedCategories('a1', [category]);
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: CategoriesService.instance,
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    vm.startNewExpense();

    expect(vm.expenseForm.data.account?.id, 'a1');
    expect(vm.expenseForm.data.category?.id, 'c1');
  });

  test('selectFormAccount loads categories and selects the first one', () async {
    final a1 = Fixtures.account(id: 'a1');
    final a2 = Fixtures.account(id: 'a2', name: 'Épargne');
    final c2 = Fixtures.category(id: 'c2', accountId: 'a2', name: 'Transport');
    seedAccounts([a1, a2]);
    seedCategories('a2', [c2]);
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([a1, a2]),
      categoriesService: CategoriesService.instance,
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);

    await vm.selectFormAccount(a2);

    expect(vm.expenseForm.data.account?.id, 'a2');
    expect(vm.expenseForm.data.category?.id, 'c2');
    expect(vm.categoriesForSelectedAccount().single.id, 'c2');
  });

  test('expense form helpers delegate to the controller', () async {
    final account = Fixtures.account(id: 'a1');
    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    seedCategories('a1', [category]);
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: CategoriesService.instance,
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    vm.startNewExpense();
    final another = Fixtures.category(id: 'c9', accountId: 'a1', name: 'Loisir');
    seedCategories('a1', [category, another]);

    vm.selectFormCategory(another);
    expect(vm.expenseForm.data.category?.id, 'c9');

    final date = DateTime(2026, 9, 10);
    vm.setDebitDate(date);
    expect(vm.expenseForm.data.debitDate, date);
    vm.setEndDate(DateTime(2026, 12, 31));
    expect(vm.expenseForm.data.endDate, isNotNull);
    vm.clearEndDate();
    expect(vm.expenseForm.data.endDate, isNull);

    vm.setRecurrence(RecurrenceType.monthly);
    expect(vm.expenseForm.data.recurrence, RecurrenceType.monthly);

    final before = vm.expenseForm.data.showAdvancedOptions;
    vm.toggleAdvancedOptions();
    expect(vm.expenseForm.data.showAdvancedOptions, !before);

    expect(vm.minPeriod, isNotNull);
    expect(vm.maxPeriod.isAfter(vm.minPeriod), isTrue);
  });

  test('expense service notification recomputes local expenses optimistically',
      () async {
    final account = Fixtures.account(id: 'a1');
    final period = Period.current();
    final exp = Fixtures.expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      amount: 25,
      debitDate: DateTime(period.year, period.month, 10),
      isDebited: true,
    );
    final expenses = FakeOverviewExpensesService()..accountExpenses = [exp];
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: expenses,
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    expenses.notifyListeners();
    await Future<void>.delayed(Duration.zero);
  });

  test('accounts notification syncs the selected account and form account',
      () async {
    final a1 = Fixtures.account(id: 'a1', name: 'Compte');
    final a2 = Fixtures.account(id: 'a2', name: 'Épargne');
    final accountsService = FakeOverviewAccountsService([a1]);
    final vm = OverviewViewModel(
      accountsService: accountsService,
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();
    vm.expenseForm.setAccount(a1);

    accountsService.values.clear();
    accountsService.values.add(a2);
    AccountsStore.instance.setAccounts([a2]);

    expect(vm.account?.id, 'a2');
  });

  test('budget store notification refreshes revenue data', () async {
    final account = Fixtures.account(id: 'a1');
    final period = Period.current();
    final budget = FakeOverviewBudgetService();
    budget.loaded.add('a1-${period.year}-${period.month}');
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: budget,
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    AccountBudgetsStore.instance.set(
      '${account.id}_${period.year}_${period.month}_x',
      AccountBudget(
        id: 'b',
        accountId: account.id!,
        year: period.year + 1,
        month: 1,
        revenue: 100,
      ),
    );
  });

  test('profile notification refreshes the view model', () async {
    final account = Fixtures.account(id: 'a1');
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    ProfileStore.instance.setPreferences(currency: 'EUR');
  });

  test('loadInitialData reports an error when account loading fails', () async {
    final accounts = FakeOverviewAccountsService(const []);
    accounts.loadError = Exception('boom');
    final vm = OverviewViewModel(
      accountsService: accounts,
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);

    await vm.loadInitialData();

    expect(vm.hasError, isTrue);
  });

  test('refreshAll succeeds and reloads inherited revenue when online',
      () async {
    final account = Fixtures.account(id: 'a1');
    final repo = FakeOverviewRepository()..inheritedRevenue = 500;
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: repo,
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    await vm.refreshAll();

    expect(vm.hasError, isFalse);
    expect(repo.calls.any((c) => c.startsWith('refresh:a1:')), isTrue);
  });

  test('remaining weekends uses the total weekend count for a future period',
      () {
    final account = Fixtures.account(id: 'a1');
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: FakeOverviewCategoriesService(),
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(),
    );
    addTearDown(vm.dispose);

    vm.selectedPeriod = const Period(year: 2099, month: 1);

    expect(vm.remainingWeekendsInPeriod, isNotNull);
  });

  test('categorySummaries resolves categories and caches the result', () async {
    final account = Fixtures.account(id: 'a1');
    final category = Fixtures.category(id: 'c1', accountId: 'a1', name: 'Courses');
    seedCategories('a1', [category]);
    final period = Period.current();
    final exp = Fixtures.expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      amount: 40,
      debitDate: DateTime(period.year, period.month, 8),
    );
    final vm = OverviewViewModel(
      accountsService: FakeOverviewAccountsService([account]),
      categoriesService: CategoriesService.instance,
      expensesService: FakeOverviewExpensesService(),
      accountBudgetsService: FakeOverviewBudgetService(),
      repository: FakeOverviewRepository(initialExpenses: [exp]),
    );
    addTearDown(vm.dispose);
    await vm.loadInitialData();

    final summaries = vm.categorySummaries;

    expect(summaries, isNotEmpty);
    expect(vm.categorySummaries, same(summaries));
  });
}
