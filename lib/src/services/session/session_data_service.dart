import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';

class SessionDataService {
  static SessionDataService? _instance;

  static SessionDataService get instance {
    _instance ??= SessionDataService._();
    return _instance!;
  }

  SessionDataService._();

  void clearUserData() {
    AccountsService.instance.clearLocalAccounts();
    CategoriesService.instance.invalidateCache();
    ExpensesService.instance.invalidateCache();
    AccountBudgetsService.instance.invalidateCache();
  }
}
