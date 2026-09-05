import 'package:budgly/src/core/navigation/app_routes.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app route constants are stable', () {
    expect(AppRoutes.login, '/login');
    expect(AppRoutes.tutorial, '/tutorial');
    expect(AppRoutes.overview, '/overview');
    expect(AppRoutes.settings, '/settings');
    expect(AppRoutes.categoryExpenses, '/overview/category');
  });

  test('category route omits period query when absent', () {
    expect(AppRoutes.categoryExpensesPath('a', 'c'), '/overview/category/a/c');
  });

  test('category route encodes period query when supplied', () {
    const period = Period(year: 2026, month: 8);
    expect(
      AppRoutes.categoryExpensesPath('a', 'c', year: period.year, month: period.month),
      '/overview/category/a/c?year=2026&month=8',
    );
  });
}
