import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_budgets_provider.g.dart';

class AccountBudgetsSessionState {
  const AccountBudgetsSessionState({
    required this.budgets,
    required this.loadedKeys,
  });
  final Map<String, AccountBudget?> budgets;
  final Set<String> loadedKeys;
}

@Riverpod(keepAlive: true)
class AccountBudgetsSession extends _$AccountBudgetsSession {
  @override
  AccountBudgetsSessionState build() =>
      const AccountBudgetsSessionState(budgets: {}, loadedKeys: {});

  String _key(String accountId, int year, int month) =>
      '${accountId}_${year}_$month';

  double getRevenue(String accountId, int year, int month) =>
      state.budgets[_key(accountId, year, month)]?.revenue ?? 0;
  bool hasLoaded(String accountId, int year, int month) =>
      state.loadedKeys.contains(_key(accountId, year, month));

  Future<AccountBudget?> loadRevenue(
    String accountId,
    int year,
    int month, {
    bool forceRefresh = false,
  }) async {
    final key = _key(accountId, year, month);
    final budget = await ref
        .read(accountBudgetsServiceProvider)
        .loadRevenue(
          accountId,
          year,
          month,
          forceRefresh: forceRefresh,
          // RL-01 §3.2: push a later background revalidation into the
          // session too, so Revenue/Overview rebuild instead of staying
          // stuck on the cache-first snapshot returned below.
          onRevalidated: (remote) => _set(key, remote),
        );
    _set(key, budget);
    return budget;
  }

  Future<void> setRevenue(
    String accountId,
    int year,
    int month,
    double revenue,
  ) async {
    final budget = await ref
        .read(accountBudgetsServiceProvider)
        .setRevenue(accountId, year, month, revenue);
    _set(_key(accountId, year, month), budget);
  }

  void clearAccount(String accountId) {
    final prefix = '${accountId}_';
    final next = Map<String, AccountBudget?>.from(state.budgets)
      ..removeWhere((k, _) => k.startsWith(prefix));
    state = AccountBudgetsSessionState(
      budgets: Map.unmodifiable(next),
      loadedKeys: {...state.loadedKeys}
        ..removeWhere((k) => k.startsWith(prefix)),
    );
    ref.read(accountBudgetsServiceProvider).invalidateCache();
  }

  void clear() {
    state = const AccountBudgetsSessionState(budgets: {}, loadedKeys: {});
    ref.read(accountBudgetsServiceProvider).invalidateCache();
  }

  void _set(String key, AccountBudget? budget) {
    final next = Map<String, AccountBudget?>.from(state.budgets)
      ..[key] = budget;
    state = AccountBudgetsSessionState(
      budgets: Map.unmodifiable(next),
      loadedKeys: {...state.loadedKeys, key},
    );
  }
}
