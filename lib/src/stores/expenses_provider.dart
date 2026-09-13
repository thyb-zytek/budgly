import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/stores/expenses.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expenses_provider.g.dart';

/// Riverpod-observable mirror of [ExpensesStore] (issue M2).
///
/// Same pattern as `AccountsSession`: [ExpensesStore] is not rewritten, its
/// only consumer today is `ExpensesService`
/// (`lib/src/services/expenses/expenses_service.dart`), not yet migrated
/// (issue M3) — it also registers the offline sync handler and drives
/// `SyncManager`, which is exactly why its rewrite is deferred rather than
/// bundled into this store-mirroring pass.
///
/// Note on cost: the store can hold a sizeable amount of expense data.
/// [_readState] only takes a shallow copy of the per-account map — the
/// inner `List<Expense>` references are reused as-is from the store, and
/// the store itself only replaces the list for the account that actually
/// changed. A `ref.watch(expensesSessionProvider.select((s) =>
/// s.expensesByAccount[accountId]))` on an unrelated account therefore
/// still skips rebuilds via plain reference equality, without needing a
/// custom deep `==` on this state class (deliberately not added).
class ExpensesSessionState {
  const ExpensesSessionState({
    required this.expensesByAccount,
    required this.loadedAccounts,
  });

  final Map<String, List<Expense>> expensesByAccount;
  final Set<String> loadedAccounts;
}

@Riverpod(keepAlive: true)
class ExpensesSession extends _$ExpensesSession {
  ExpensesStore get _store => ExpensesStore.instance;

  @override
  ExpensesSessionState build() {
    _store.addListener(_onStoreChanged);
    ref.onDispose(() => _store.removeListener(_onStoreChanged));
    return _readState();
  }

  ExpensesSessionState _readState() => ExpensesSessionState(
        expensesByAccount: _store.expensesByAccount,
        loadedAccounts: _store.loadedAccounts,
      );

  void _onStoreChanged() {
    state = _readState();
  }
}
