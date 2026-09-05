import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Minimal fake provider for [AccountBudgetsService] tests.
/// Keeps budgets in memory and simulates cache vs server sources.
class FakeAccountBudgetProvider extends AccountBudgetFirestore {
  final Map<String, AccountBudget?> store = {};
  int getCalls = 0;
  int mostRecentCalls = 0;

  String _key(String accountId, int year, int month) => '${accountId}_${year}_$month';

  @override
  Future<AccountBudget?> get(String accountId, int year, int month, {Source source = Source.server}) async {
    getCalls++;
    return store[_key(accountId, year, month)];
  }

  @override
  Future<AccountBudget?> getMostRecentWithRevenue(String accountId, {required Period before, Source source = Source.server}) async {
    mostRecentCalls++;
    return firstRevenueBefore(store.values.whereType<AccountBudget>().toList(), before);
  }

  @override
  Future<AccountBudget> setRevenue(String accountId, int year, int month, double revenue) async {
    final budget = AccountBudget(
      id: _key(accountId, year, month),
      accountId: accountId,
      year: year,
      month: month,
      revenue: revenue,
    );
    store[_key(accountId, year, month)] = budget;
    return budget;
  }
}
