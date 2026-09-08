import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';

/// Period-scoped expense cache and optimistic merge policy.
///
/// This is deliberately small and has no knowledge of Firestore, sync or UI.
/// Keeping it separate makes the cache policy independently testable while
/// leaving [ExpensesService] responsible for orchestration.
class ExpensePeriodCache {
  final Map<String, List<Expense>> _cache = {};
  final Map<String, Future<List<Expense>>> _inFlight = {};

  /// Ids of expenses created locally but not yet acknowledged by a server
  /// refresh. They are protected from being dropped by stale snapshots.
  final Set<String> _optimisticIds = {};
  final Map<String, Expense> _pending = {};
  final Set<String> _pendingDeletes = {};

  String key(String accountId, Period period, String? categoryId) =>
      '$accountId|$period|${categoryId ?? '*'}';

  List<Expense>? cached(String key) => _cache[key];

  void put(String key, List<Expense> expenses) {
    _cache[key] = List<Expense>.from(expenses);
  }

  List<Expense> ensure(String key) => _cache.putIfAbsent(key, () => []);

  void addOptimistic(String expenseId) {
    _optimisticIds.add(expenseId);
  }

  void markPending(String expenseId, Expense expense) {
    _pendingDeletes.remove(expenseId);
    _pending[expenseId] = expense;
  }

  void markPendingDelete(String expenseId) {
    _pending.remove(expenseId);
    _pendingDeletes.add(expenseId);
  }

  void clearPending(String? expenseId) {
    if (expenseId == null) return;
    _pending.remove(expenseId);
    _pendingDeletes.remove(expenseId);
    _optimisticIds.remove(expenseId);
  }

  /// Releases the optimistic shield for expenses the server has now confirmed
  /// in a fresh snapshot.
  ///
  /// Protection must not be released on a local write success alone: Firestore
  /// queues offline writes locally, so a subsequent server query can still lag
  /// behind and would otherwise drop the just-created expense during
  /// [mergeServer]. Only a refresh that actually returns the expense proves
  /// the server has acknowledged it.
  void releaseConfirmed(List<Expense> serverExpenses) {
    for (final serverExpense in serverExpenses) {
      final id = serverExpense.id;
      if (id != null &&
          (_pending.containsKey(id) || _optimisticIds.contains(id))) {
        clearPending(id);
      }
    }
  }

  /// Merges a server snapshot with unconfirmed optimistic creations so a
  /// freshly created expense survives a refresh that returns stale data.
  ///
  /// Once the server acknowledges an id it is no longer protected, so a
  /// deletion performed on another device still propagates server-side.
  List<Expense> mergeServer(String key, List<Expense> serverExpenses) {
    final existing = _cache[key] ?? const <Expense>[];
    final merged = <Expense>[];
    final seen = <String>{};

    for (final serverExpense in serverExpenses) {
      final id = serverExpense.id;
      if (id != null && _pendingDeletes.contains(id)) continue;
      final resolved = id == null ? serverExpense : (_pending[id] ?? serverExpense);
      if (resolved.id == null || seen.add(resolved.id!)) merged.add(resolved);
    }

    for (final local in existing) {
      final id = local.id;
      if (id == null || seen.contains(id) || _pendingDeletes.contains(id)) continue;
      if (_pending.containsKey(id) || _optimisticIds.contains(id)) {
        merged.add(_pending[id] ?? local);
        seen.add(id);
      }
    }

    merged.sort((a, b) => b.debitDate.compareTo(a.debitDate));
    return merged;
  }

  Future<List<Expense>>? inFlight(String key) => _inFlight[key];

  void setInFlight(String key, Future<List<Expense>> future) {
    _inFlight[key] = future;
  }

  void clearInFlight(String key, Future<List<Expense>> future) {
    if (identical(_inFlight[key], future)) _inFlight.remove(key);
  }

  void removeAccount(String accountId) {
    _cache.removeWhere((key, _) => key.startsWith('$accountId|'));
    _inFlight.removeWhere((key, _) => key.startsWith('$accountId|'));
  }

  /// Clears every cached period of the account except [keepKey].
  ///
  /// Used when a recurring series is created: the debit-date period already
  /// holds the optimistic expense, but the series projects into every other
  /// covered period, whose caches are now stale and must be reloaded on the
  /// next visit instead of serving a stale snapshot.
  void removeAccountExcept(String accountId, String keepKey) {
    _cache.removeWhere(
      (key, _) => key.startsWith('$accountId|') && key != keepKey,
    );
    _inFlight.removeWhere(
      (key, _) => key.startsWith('$accountId|') && key != keepKey,
    );
  }

  void optimisticUpdateExpense(Expense oldExpense, Expense newExpense) {
    final oldIsRecurring = oldExpense.isRecurring;
    final newIsRecurring = newExpense.isRecurring;
    if (oldIsRecurring || newIsRecurring) {
      removeAccount(oldExpense.accountId);
      if (newExpense.accountId != oldExpense.accountId) {
        removeAccount(newExpense.accountId);
      }
      return;
    }

    final oldPeriod = Period.fromDate(oldExpense.debitDate);
    final newPeriod = Period.fromDate(newExpense.debitDate);
    final oldAccountId = oldExpense.accountId;
    final newAccountId = newExpense.accountId;

    if (oldAccountId == newAccountId && oldPeriod == newPeriod) {
      final cacheKey = key(oldAccountId, oldPeriod, null);
      final list = _cache[cacheKey];
      if (list != null) {
        final index = list.indexWhere((e) => e.id == oldExpense.id);
        if (index != -1) {
          list[index] = newExpense;
        }
      }
      return;
    }

    // Moved between periods or accounts: remove from old, add to new.
    final oldKey = key(oldAccountId, oldPeriod, null);
    final oldList = _cache[oldKey];
    if (oldList != null) {
      oldList.removeWhere((e) => e.id == oldExpense.id);
    }

    final newKey = key(newAccountId, newPeriod, null);
    final newList = _cache[newKey];
    if (newList != null) {
      if (!newList.any((e) => e.id == newExpense.id)) {
        newList.add(newExpense);
        newList.sort((a, b) => b.debitDate.compareTo(a.debitDate));
      } else {
        final idx = newList.indexWhere((e) => e.id == newExpense.id);
        if (idx != -1) newList[idx] = newExpense;
      }
    }
    // Unloaded caches remain absent and will be populated on the next load.
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
    _optimisticIds.clear();
    _pending.clear();
    _pendingDeletes.clear();
  }
}
