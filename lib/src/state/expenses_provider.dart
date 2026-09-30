import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expenses_provider.g.dart';

/// Shared in-memory expense state. This is the application source of truth;
/// [ExpensesService] only handles persistence/sync and narrowly-scoped
/// technical caching needed by those mechanisms.
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
  @override
  ExpensesSessionState build() {
    return const ExpensesSessionState(
      expensesByAccount: {},
      loadedAccounts: {},
    );
  }

  List<Expense> getExpensesForAccount(String accountId) =>
      state.expensesByAccount[accountId] ?? const [];

  Expense? getExpenseById(String expenseId) {
    for (final expenses in state.expensesByAccount.values) {
      for (final expense in expenses) {
        if (expense.id == expenseId) return expense;
      }
    }
    return null;
  }

  Future<List<Expense>> loadAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async {
    final expenses = await ref
        .read(expensesServiceProvider)
        .listExpensesForAccount(accountId, forceRefresh: forceRefresh);
    _setAccount(accountId, expenses);
    return expenses;
  }

  Future<List<Expense>> loadPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    bool forceRefresh = false,
  }) async {
    final expenses = await ref
        .read(expensesServiceProvider)
        .listExpensesForPeriod(
          accountId,
          period,
          categoryId: categoryId,
          forceRefresh: forceRefresh,
          // RL-01 §3.2: the service may still be revalidating against the
          // server in the background when this returns (cache-first hit).
          // Push that later result into the session too, otherwise Overview
          // (and any other PeriodExpenses watcher) never learns the server
          // confirmed/changed the data and stays rendered from stale cache.
          onRevalidated: (remote) => _mergeAccount(accountId, remote),
        );
    _mergeAccount(accountId, expenses);
    return expenses;
  }

  Future<Expense> create(Expense expense) async {
    final created = await ref
        .read(expensesServiceProvider)
        .createExpense(expense);
    _upsert(created);
    return created;
  }

  Future<Expense> update(Expense expense, {Expense? previous}) async {
    final updated = await ref
        .read(expensesServiceProvider)
        .updateExpense(expense, previous: previous);
    _upsert(updated);
    return updated;
  }

  Future<bool> delete(String expenseId, String accountId) async {
    final result = await ref
        .read(expensesServiceProvider)
        .deleteExpense(expenseId, accountId);
    if (result) _remove(expenseId, accountId);
    return result;
  }

  /// Pushes an already-known-fresh [Expense] (e.g. returned by a service call
  /// made by a feature-specific Notifier) into the shared session state
  /// without re-fetching. Mirrors `AccountsSession.updateLocal`.
  void updateLocal(Expense expense) => _upsert(expense);

  /// Removes a locally-deleted expense from the shared session state.
  /// Mirrors `AccountsSession`'s local-removal helpers.
  void removeLocal(String expenseId, String accountId) =>
      _remove(expenseId, accountId);

  void clearAccount(String accountId) {
    final next = Map<String, List<Expense>>.from(state.expensesByAccount)
      ..remove(accountId);
    state = ExpensesSessionState(
      expensesByAccount: Map.unmodifiable(next),
      loadedAccounts: {...state.loadedAccounts}..remove(accountId),
    );
    ref.read(expensesServiceProvider).invalidateCache();
  }

  void clear() {
    state = const ExpensesSessionState(
      expensesByAccount: {},
      loadedAccounts: {},
    );
    ref.read(expensesServiceProvider).invalidateCache();
  }

  void _setAccount(String accountId, List<Expense> expenses) {
    final next = Map<String, List<Expense>>.from(state.expensesByAccount)
      ..[accountId] = List.unmodifiable(expenses);
    state = ExpensesSessionState(
      expensesByAccount: Map.unmodifiable(next),
      loadedAccounts: {...state.loadedAccounts, accountId},
    );
  }

  void _mergeAccount(String accountId, List<Expense> expenses) {
    final byId = {
      for (final e in getExpensesForAccount(accountId))
        if (e.id != null) e.id!: e,
    };
    for (final e in expenses) {
      if (e.id != null) byId[e.id!] = e;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.debitDate.compareTo(a.debitDate));
    _setAccount(accountId, merged);
  }

  void _upsert(Expense expense) => _mergeAccount(expense.accountId, [expense]);

  void _remove(String id, String accountId) {
    final next = Map<String, List<Expense>>.from(state.expensesByAccount)
      ..[accountId] = List.unmodifiable(
        getExpensesForAccount(accountId).where((e) => e.id != id),
      );
    state = ExpensesSessionState(
      expensesByAccount: Map.unmodifiable(next),
      loadedAccounts: state.loadedAccounts,
    );
  }
}
