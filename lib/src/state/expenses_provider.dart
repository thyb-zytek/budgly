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

  int _sessionRevision = 0;
  final Map<String, int> _accountRevisions = {};

  int _accountRevision(String accountId) => _accountRevisions[accountId] ?? 0;

  void _bumpAccountRevision(String accountId) {
    _accountRevisions[accountId] = _accountRevision(accountId) + 1;
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
    final sessionRevision = _sessionRevision;
    final accountRevision = _accountRevision(accountId);
    final expenses = await ref
        .read(expensesServiceProvider)
        .listExpensesForAccount(accountId, forceRefresh: forceRefresh);
    if (ref.mounted &&
        sessionRevision == _sessionRevision &&
        accountRevision == _accountRevision(accountId)) {
      _setAccount(accountId, expenses);
    }
    return expenses;
  }

  Future<List<Expense>> loadPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    bool forceRefresh = false,
  }) async {
    final sessionRevision = _sessionRevision;
    final accountRevision = _accountRevision(accountId);
    final expenses = await ref
        .read(expensesServiceProvider)
        .listExpensesForPeriod(
          accountId,
          period,
          categoryId: categoryId,
          forceRefresh: forceRefresh,
          // Cache revalidation may complete after logout/account clearing.
          // Never merge data once its owning session has been invalidated.
          onRevalidated: (remote) {
            if (ref.mounted &&
                sessionRevision == _sessionRevision &&
                accountRevision == _accountRevision(accountId)) {
              _mergeAccount(accountId, remote);
            }
          },
        );
    if (ref.mounted &&
        sessionRevision == _sessionRevision &&
        accountRevision == _accountRevision(accountId)) {
      _mergeAccount(accountId, expenses);
    }
    return expenses;
  }

  Future<Expense> create(Expense expense) async {
    final sessionRevision = _sessionRevision;
    _bumpAccountRevision(expense.accountId);
    final created = await ref
        .read(expensesServiceProvider)
        .createExpense(expense);
    if (ref.mounted && sessionRevision == _sessionRevision) _upsert(created);
    return created;
  }

  Future<Expense> update(Expense expense, {Expense? previous}) async {
    final sessionRevision = _sessionRevision;
    _bumpAccountRevision(expense.accountId);
    final updated = await ref
        .read(expensesServiceProvider)
        .updateExpense(expense, previous: previous);
    if (ref.mounted && sessionRevision == _sessionRevision) _upsert(updated);
    return updated;
  }

  Future<bool> delete(String expenseId, String accountId) async {
    final sessionRevision = _sessionRevision;
    _bumpAccountRevision(accountId);
    final result = await ref
        .read(expensesServiceProvider)
        .deleteExpense(expenseId, accountId);
    if (result && ref.mounted && sessionRevision == _sessionRevision) {
      _remove(expenseId, accountId);
    }
    return result;
  }

  /// Pushes an already-known-fresh [Expense] (e.g. returned by a service call
  /// made by a feature-specific Notifier) into the shared session state
  /// without re-fetching. Mirrors `AccountsSession.updateLocal`.
  void updateLocal(Expense expense) {
    _bumpAccountRevision(expense.accountId);
    _upsert(expense);
  }

  /// Removes a locally-deleted expense from the shared session state.
  /// Mirrors `AccountsSession`'s local-removal helpers.
  void removeLocal(String expenseId, String accountId) {
    _bumpAccountRevision(accountId);
    _remove(expenseId, accountId);
  }

  void clearAccount(String accountId) {
    _bumpAccountRevision(accountId);
    final next = Map<String, List<Expense>>.from(state.expensesByAccount)
      ..remove(accountId);
    state = ExpensesSessionState(
      expensesByAccount: Map.unmodifiable(next),
      loadedAccounts: {...state.loadedAccounts}..remove(accountId),
    );
    ref.read(expensesServiceProvider).invalidateCache();
  }

  void clear() {
    _sessionRevision++;
    _accountRevisions.clear();
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
