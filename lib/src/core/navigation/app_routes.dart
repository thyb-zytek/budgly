abstract final class AppRoutes {
  static const login = '/login';
  static const tutorial = '/tutorial';
  static const overview = '/overview';
  static const settings = '/settings';
  static const categoryExpenses = '/overview/category';
  static const undebitedExpenses = '/overview/undebited';

  static String categoryExpensesPath(
    String accountId,
    String categoryId, {
    int? year,
    int? month,
  }) {
    final path = '$categoryExpenses/$accountId/$categoryId';
    if (year == null || month == null) return path;
    return '$path?year=$year&month=$month';
  }
}
