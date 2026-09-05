import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/stores/accounts_budget.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/stores/expenses.dart';

/// Test-only helpers to reset singleton stores without exposing internals.
///
/// Each singleton holds an in-memory cache. Clearing it between tests gives
/// deterministic fixtures without needing to mock ChangeNotifier plumbing.
void clearAllTestStores() {
  AccountsStore.instance.clearLocalAccounts();
  AccountBudgetsStore.instance.clearAll();
  CategoriesStore.instance.clearAll();
  ExpensesStore.instance.clearAll();
}

void seedAccounts(List<Account> accounts) {
  AccountsStore.instance.setAccounts(accounts);
}

void seedCategories(String accountId, List<Category> categories) {
  CategoriesStore.instance.setCategoriesForAccount(accountId, categories);
}

void seedExpenses(String accountId, List<Expense> expenses) {
  ExpensesStore.instance.setExpensesForAccount(accountId, expenses);
}
