import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';

/// Coordinates the data sources required by the Overview screen.
///
/// This is intentionally a thin composition layer: domain logic remains in
/// the existing services and UI state remains in [OverviewViewModel]. It
/// exists to keep account/period loading orchestration out of the ViewModel
/// and to make that orchestration independently replaceable in tests.
class OverviewRepository {
  final CategoriesService categoriesService;
  final ExpensesService expensesService;
  final AccountBudgetsService accountBudgetsService;

  OverviewRepository({
    CategoriesService? categoriesService,
    ExpensesService? expensesService,
    AccountBudgetsService? accountBudgetsService,
  }) : categoriesService = categoriesService ?? CategoriesService.instance,
       expensesService = expensesService ?? ExpensesService.instance,
       accountBudgetsService =
           accountBudgetsService ?? AccountBudgetsService.instance;

  Future<List<Expense>> loadInitialData(Account account, Period period) async {
    final accountId = account.id;
    if (accountId == null) return const [];

    final expensesFuture = expensesService.listExpensesForPeriod(accountId, period);
    await Future.wait([
      categoriesService.listCategoriesByAccount(accountId),
      expensesFuture,
    ]);
    return expensesFuture;
  }

  Future<void> refresh(Account account, Period period) async {
    final accountId = account.id;
    if (accountId == null) return;

    await Future.wait([
      categoriesService.listCategoriesByAccount(
        accountId,
        forceRefresh: true,
      ),
      expensesService.listExpensesForPeriod(
        accountId,
        period,
        forceRefresh: true,
      ),
      accountBudgetsService.loadRevenue(
        accountId,
        period.year,
        period.month,
        forceRefresh: true,
      ),
    ]);
  }

  Future<List<Expense>> loadPeriodExpenses(
    String accountId,
    Period period, {
    bool forceRefresh = false,
  }) {
    return expensesService.listExpensesForPeriod(
      accountId,
      period,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> loadRevenueInBackground(
    String accountId,
    int year,
    int month,
  ) async {
    try {
      await accountBudgetsService.loadRevenue(accountId, year, month);
    } catch (e) {
      AppLogger.debug('Background revenue load unavailable: $e');
    }
  }

  Future<double?> getMostRecentRevenue(
    String accountId, {
    required Period before,
  }) {
    return accountBudgetsService.getMostRecentRevenue(
      accountId,
      before: before,
    );
  }
}
