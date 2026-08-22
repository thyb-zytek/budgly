import 'package:budgly/src/core/navigation/app_router.dart';
import 'package:budgly/src/core/navigation/app_routes.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:go_router/go_router.dart';

/// Compatibility facade for callers that only need route names or the router.
/// Route definitions themselves live in [AppRouter].
abstract final class NavigationHelper {
  static GoRouter get router => AppRouter.router;

  static const loginPath = AppRoutes.login;
  static const tutorialPath = AppRoutes.tutorial;
  static const overviewPath = AppRoutes.overview;
  static const settingsPath = AppRoutes.settings;
  static const categoryExpensesPath = AppRoutes.categoryExpenses;

  static String buildCategoryExpensesPath(
    String accountId,
    String categoryId,
    Period? period,
  ) {
    return AppRoutes.categoryExpensesPath(
      accountId,
      categoryId,
      year: period?.year,
      month: period?.month,
    );
  }
}
