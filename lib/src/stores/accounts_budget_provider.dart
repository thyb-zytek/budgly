import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/stores/accounts_budget.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'accounts_budget_provider.g.dart';

/// Riverpod-observable mirror of [AccountBudgetsStore] (issue M2).
///
/// Same pattern as `AccountsSession`: [AccountBudgetsStore] is not
/// rewritten, its only consumer today is `AccountBudgetsService`
/// (`lib/src/services/budget/account_budgets_service.dart`), not yet
/// migrated (issue M3).
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
  AccountBudgetsStore get _store => AccountBudgetsStore.instance;

  @override
  AccountBudgetsSessionState build() {
    _store.addListener(_onStoreChanged);
    ref.onDispose(() => _store.removeListener(_onStoreChanged));
    return _readState();
  }

  AccountBudgetsSessionState _readState() => AccountBudgetsSessionState(
        budgets: _store.budgets,
        loadedKeys: _store.loadedKeys,
      );

  void _onStoreChanged() {
    state = _readState();
  }
}
