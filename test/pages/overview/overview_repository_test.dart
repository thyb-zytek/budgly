import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/pages/overview/overview_repository.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCategoriesService extends CategoriesService {
  final List<String> calls = [];

  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async {
    calls.add('$accountId:$forceRefresh');
    return const <Category>[];
  }
}

class FakeExpensesService extends ExpensesService {
  final List<String> calls = [];
  final List<Expense> result;

  FakeExpensesService([this.result = const []]);

  @override
  Future<List<Expense>> listExpensesForPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    bool forceRefresh = false,
  }) async {
    calls.add('$accountId:$period:$forceRefresh');
    return result;
  }
}

class FakeBudgetsService extends AccountBudgetsService {
  final List<String> calls = [];

  @override
  Future<void> loadRevenue(
    String accountId,
    int year,
    int month, {
    bool forceRefresh = false,
  }) async {
    calls.add('$accountId:$year:$month:$forceRefresh');
  }

  @override
  Future<double?> getMostRecentRevenue(
    String accountId, {
    required Period before,
  }) async {
    calls.add('recent:$accountId:${before.year}-${before.month}');
    return 1234;
  }
}

void main() {
  const period = Period(year: 2026, month: 8);
  const account = Account(id: 'a1', name: 'Compte');

  test('loadInitialData loads categories and expenses and returns expenses', () async {
    final categories = FakeCategoriesService();
    final expenses = FakeExpensesService(const []);
    final repository = OverviewRepository(
      categoriesService: categories,
      expensesService: expenses,
    );

    final result = await repository.loadInitialData(account, period);

    expect(result, isEmpty);
    expect(categories.calls, ['a1:false']);
    expect(expenses.calls, ['a1:$period:false']);
  });

  test('refresh forces category, expense and revenue reloads', () async {
    final categories = FakeCategoriesService();
    final expenses = FakeExpensesService();
    final budgets = FakeBudgetsService();
    final repository = OverviewRepository(
      categoriesService: categories,
      expensesService: expenses,
      accountBudgetsService: budgets,
    );

    await repository.refresh(account, period);

    expect(categories.calls, ['a1:true']);
    expect(expenses.calls, ['a1:$period:true']);
    expect(budgets.calls, ['a1:2026:8:true']);
  });

  test('loadRevenueInBackground delegates and swallows failures', () async {
    final budgets = FakeBudgetsService();
    final repository = OverviewRepository(accountBudgetsService: budgets);

    await repository.loadRevenueInBackground('a1', 2026, 8);

    expect(budgets.calls, ['a1:2026:8:false']);
  });

  test('getMostRecentRevenue delegates to the budget service', () async {
    final budgets = FakeBudgetsService();
    final repository = OverviewRepository(accountBudgetsService: budgets);

    expect(
      await repository.getMostRecentRevenue(
        'a1',
        before: const Period(year: 2026, month: 8),
      ),
      1234,
    );
    expect(budgets.calls, ['recent:a1:2026-8']);
  });
}
