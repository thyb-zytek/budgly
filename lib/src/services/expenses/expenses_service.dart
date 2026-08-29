import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/calculators/recurring_expense_versioning.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:budgly/src/services/offline/offline_id.dart';
import 'package:budgly/src/stores/expenses.dart';

class ExpensesService extends ChangeNotifier {
  static ExpensesService? _instance;

  static ExpensesService get instance {
    _instance ??= ExpensesService._();
    return _instance!;
  }

  final ExpenseFirestore _expenseFirestore;
  final ExpensesStore _store;
  final RecurringExpenseVersioning _recurringVersioning;

  final _periodData = _ExpensePeriodData();

  ExpensesService({
    ExpenseFirestore? expenseFirestore,
    ExpensesStore? store,
    RecurringExpenseVersioning? recurringVersioning,
  }) : _expenseFirestore = expenseFirestore ?? ExpenseFirestore(),
       _store = store ?? ExpensesStore.instance,
       _recurringVersioning =
           recurringVersioning ?? const RecurringExpenseVersioning() {
    _store.addListener(notifyListeners);
  }

  ExpensesService._() : this();

  @override
  void dispose() {
    _store.removeListener(notifyListeners);
    super.dispose();
  }

  void invalidateCache() {
    _periodData.clear();
    _store.clearAll();
  }


  Future<List<Expense>> listExpensesForPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    bool forceRefresh = false,
  }) async {
    final key = _periodData.key(accountId, period, categoryId);
    final memoryCached = _periodData.cached(key);
    if (!forceRefresh && memoryCached != null) {
      return List.unmodifiable(memoryCached);
    }

    if (!forceRefresh) {
      try {
        final cached = await _expenseFirestore.listByAccountAndPeriod(
          accountId,
          period,
          categoryId: categoryId,
          source: Source.cache,
        );
        if (cached.isNotEmpty) {
          _periodData.put(key, cached);

          // Firestore owns its persistent offline cache. Once local data is
          // available, never make the caller wait for the server.
          unawaited(
            _refreshPeriodInBackground(
              accountId,
              period,
              categoryId: categoryId,
              key: key,
            ),
          );
          return List.unmodifiable(cached);
        }

        // An empty cache does not mean the account has no expenses. Wait for
        // the first server response so the Overview does not briefly show an
        // empty state before its data arrives.
      } on FirebaseException catch (e) {
        // The local cache can be empty on the first launch. In that case the
        // server is needed to obtain the initial dataset.
        if (e.code != 'failed-precondition' && e.code != 'unavailable') {
          rethrow;
        }
      }
    }

    final existing = _periodData.inFlight(key);
    if (existing != null) return existing;

    final future = _refreshPeriod(
      accountId,
      period,
      categoryId: categoryId,
      key: key,
    );
    _periodData.setInFlight(key, future);
    try {
      return await future;
    } finally {
      _periodData.clearInFlight(key, future);
    }
  }

  List<Expense>? cachedExpensesForPeriod(String accountId, Period period) {
    final expenses = _periodData.cached(
      _periodData.key(accountId, period, null),
    );
    return expenses == null ? null : List.unmodifiable(expenses);
  }

  Future<void> _refreshPeriodInBackground(
    String accountId,
    Period period, {
    String? categoryId,
    required String key,
  }) async {
    try {
      await _refreshPeriod(accountId, period, categoryId: categoryId, key: key);
    } catch (e) {
      AppLogger.debug('Background expense refresh unavailable: $e');
    }
  }

  Future<List<Expense>> _refreshPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    required String key,
  }) async {
    try {
      final expenses = await _expenseFirestore.listByAccountAndPeriod(
        accountId,
        period,
        categoryId: categoryId,
        source: Source.server,
      );
      // A server snapshot can still be stale while an optimistic create is
      // being persisted (offline replay or slow network). Never let it drop
      // locally-created expenses that the server has not acknowledged yet:
      // keep the unconfirmed ones until the server returns them.
      final merged = _periodData.mergeServer(key, expenses);
      _periodData.put(key, merged);
      notifyListeners();
      return List.unmodifiable(merged);
    } catch (e) {
      AnalyticsService.instance.track('expense_load_failed', {
        'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<ExpensePage> listCategoryPeriodPage(
    String accountId,
    String categoryId,
    Period period, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    bool includeRecurring = true,
  }) {
    return _expenseFirestore
        .listByCategoryAndPeriodPage(
          accountId,
          categoryId,
          period,
          limit: limit,
          startAfter: startAfter,
          includeRecurring: includeRecurring,
        )
        .timeout(const Duration(seconds: 8));
  }

  Future<Expense> createExpense(Expense expense) async {
    final optimistic = expense.id == null
        ? expense.copyWith(id: OfflineId.uuid())
        : expense;
    final periodKey =
        '${optimistic.accountId}|${Period.fromDate(optimistic.debitDate)}|*';
    final cachedPeriod = _periodData.ensure(periodKey);
    cachedPeriod.add(optimistic);
    cachedPeriod.sort((a, b) => b.debitDate.compareTo(a.debitDate));
    _periodData.addOptimistic(optimistic.id!);
    _store.addExpense(optimistic);
    notifyListeners();
    unawaited(_persistCreatedExpense(optimistic));
    AnalyticsService.instance.track('expense_created', {
      'recurring': optimistic.isRecurring,
    });
    return optimistic;
  }

  Future<void> _persistCreatedExpense(Expense expense) async {
    try {
      final created = await _expenseFirestore.create(expense);
      if (created == null) throw Exception('Failed to create expense');
    } catch (e) {
      AnalyticsService.instance.track('expense_create_failed', {
        'error': e.toString(),
      });
      AppLogger.error('Failed to persist expense creation', e);
    }
  }

  Future<Expense> updateRecurringExpenseFromOccurrence({
    required Expense original,
    required Expense updated,
    required DateTime effectiveDate,
  }) async {
    AnalyticsService.instance.track('recurring_expense_version_changed');
    if (!original.isRecurring || original.id == null) {
      return updateExpense(updated);
    }

    final version = _recurringVersioning.split(
      original: original,
      updated: updated,
      effectiveDate: effectiveDate,
    );

    if (version.next.id == original.id) {
      return updateExpense(version.next, previous: original);
    }

    // `splitRecurringExpense` may return null (batch not committed) or, offline,
    // hang retrying the network. Never trap the user on the edit form: bound
    // the call with a timeout and apply the split optimistically with a local
    // id so the change is visible right away. A later server refresh can
    // reconcile the series.
    Expense resolved;
    try {
      final created = await _expenseFirestore
          .splitRecurringExpense(
            previous: version.previous,
            next: version.next,
          )
          .timeout(const Duration(seconds: 5));
      resolved = created ?? version.next.copyWith(id: OfflineId.uuid());
    } catch (_) {
      resolved = version.next.copyWith(id: OfflineId.uuid());
    }

    _periodData.removeAccount(resolved.accountId);
    _store.replaceExpenseWithVersions(
      previous: version.previous,
      next: resolved,
    );
    return resolved;
  }

  Future<Expense> updateExpense(Expense expense, {Expense? previous}) async {
    if (previous != null) {
      _periodData.optimisticUpdateExpense(previous, expense);
    } else {
      _periodData.removeAccount(expense.accountId);
    }
    _store.updateExpense(expense);
    unawaited(_persistExpenseUpdate(expense));
    AnalyticsService.instance.track('expense_updated', {
      'recurring': expense.isRecurring,
    });
    return expense;
  }

  Future<void> _persistExpenseUpdate(Expense expense) async {
    try {
      final success = await _expenseFirestore.update(expense);
      if (!success) throw Exception('Failed to update expense');
    } catch (e, stackTrace) {
      AnalyticsService.instance.track('expense_update_failed', {
        'error': e.toString(),
      });
      AppLogger.error('Failed to update expense', e, stackTrace);
    }
  }

  Future<bool> deleteExpense(String expenseId, String accountId) async {
    try {
      final success = await _expenseFirestore.delete(expenseId);
      if (success) {
        _periodData.removeAccount(accountId);
        _store.removeExpense(expenseId, accountId);
        AnalyticsService.instance.track('expense_deleted');
        return true;
      }
      throw Exception('Failed to delete expense');
    } catch (e, stackTrace) {
      AnalyticsService.instance.track('expense_delete_failed', {
        'error': e.toString(),
      });
      AppLogger.error('Failed to delete expense', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> deleteSingleOccurrence({
    required Expense expense,
    required DateTime occurrenceDate,
  }) async {
    if (!expense.isRecurring || expense.id == null) {
      return deleteExpense(expense.id!, expense.accountId);
    }
    final targetDay = DateTime(
      occurrenceDate.year,
      occurrenceDate.month,
      occurrenceDate.day,
    );
    final originalDay = DateTime(
      expense.debitDate.year,
      expense.debitDate.month,
      expense.debitDate.day,
    );
    final isFirst = targetDay.isAtSameMomentAs(originalDay);
    final targetKey = Expense.isoDate(targetDay);

    if (isFirst) {
      final nextDate = expense.recurrence.nextOccurrenceAfter(
        targetDay,
        anchorDay: expense.recurrenceAnchorDay,
      );
      final end = expense.endOfEndDate;
      if (end != null && nextDate.isAfter(end)) {
        return deleteExpense(expense.id!, expense.accountId);
      }
      final filteredDebited =
          expense.debitedOccurrences.where((k) => k != targetKey).toList();
      final updated = expense.copyWith(
        debitDate: nextDate,
        debitedOccurrences: filteredDebited,
      );
      await updateExpense(updated, previous: expense);
      AnalyticsService.instance.track('expense_single_occurrence_deleted');
      return true;
    }

    final previousEnd = targetDay.subtract(const Duration(days: 1));
    final previousDebited = expense.debitedOccurrences
        .where((k) => k.compareTo(targetKey) < 0)
        .toList();
    final nextDate = expense.recurrence.nextOccurrenceAfter(
      targetDay,
      anchorDay: expense.recurrenceAnchorDay,
    );
    final end = expense.endOfEndDate;
    final hasFuture = end == null || !nextDate.isAfter(end);

    if (!hasFuture) {
      final previous = expense.copyWith(
        endDate: previousEnd,
        debitedOccurrences: previousDebited,
      );
      await updateExpense(previous, previous: expense);
      AnalyticsService.instance.track('expense_single_occurrence_deleted');
      return true;
    }

    final nextDebited = expense.debitedOccurrences
        .where((k) => k.compareTo(targetKey) > 0)
        .toList();
    final previous = expense.copyWith(
      endDate: previousEnd,
      debitedOccurrences: previousDebited,
    );
    final next = Expense(
      accountId: expense.accountId,
      categoryId: expense.categoryId,
      name: expense.name,
      amount: expense.amount,
      debitDate: nextDate,
      endDate: expense.endDate,
      recurrence: expense.recurrence,
      recurrenceAnchorDay: expense.recurrenceAnchorDay,
      isDebited: false,
      debitedOccurrences: nextDebited,
    );

    try {
      final created = await _expenseFirestore
          .splitRecurringExpense(previous: previous, next: next)
          .timeout(const Duration(seconds: 5));
      final resolvedNext = created ?? next.copyWith(id: OfflineId.uuid());
      _periodData.removeAccount(expense.accountId);
      _store.replaceExpenseWithVersions(
        previous: previous,
        next: resolvedNext,
      );
      AnalyticsService.instance.track('expense_single_occurrence_deleted');
      return true;
    } catch (_) {
      final fallbackNext = next.copyWith(id: OfflineId.uuid());
      _periodData.removeAccount(expense.accountId);
      _store.replaceExpenseWithVersions(
        previous: previous,
        next: fallbackNext,
      );
      AnalyticsService.instance.track('expense_single_occurrence_deleted');
      return true;
    }
  }

  Future<bool> deleteFutureOccurrences({
    required Expense expense,
    required DateTime occurrenceDate,
  }) async {
    if (!expense.isRecurring || expense.id == null) {
      return deleteExpense(expense.id!, expense.accountId);
    }
    final targetDay = DateTime(
      occurrenceDate.year,
      occurrenceDate.month,
      occurrenceDate.day,
    );
    final originalDay = DateTime(
      expense.debitDate.year,
      expense.debitDate.month,
      expense.debitDate.day,
    );
    if (targetDay.isAtSameMomentAs(originalDay)) {
      return deleteExpense(expense.id!, expense.accountId);
    }
    final previousEnd = targetDay.subtract(const Duration(days: 1));
    final targetKey = Expense.isoDate(targetDay);
    final previousDebited = expense.debitedOccurrences
        .where((k) => k.compareTo(targetKey) < 0)
        .toList();
    final updated = expense.copyWith(
      endDate: previousEnd,
      debitedOccurrences: previousDebited,
    );
    await updateExpense(updated, previous: expense);
    AnalyticsService.instance.track('expense_future_occurrences_deleted');
    return true;
  }

  Expense? getExpenseById(String expenseId) => _store.getExpenseById(expenseId);

  List<Expense> getExpensesForAccount(String accountId) =>
      _store.getExpensesForAccount(accountId);

  Future<void> deleteByAccountId(String accountId) async {
    await _expenseFirestore.deleteByAccountId(accountId);
    _store.clearAccountCache(accountId);
  }

  Future<void> deleteByCategoryId(String categoryId) async {
    await _expenseFirestore.deleteByCategoryId(categoryId);
    _store.clearCategoryCache(categoryId);
  }

  Future<Expense> markOccurrenceDebited(Expense expense, DateTime date) async {
    if (expense.isRecurring) {
      final key = Expense.isoDate(date);
      if (expense.debitedOccurrences.contains(key)) return expense;
      return updateExpense(
        expense.copyWith(
          debitedOccurrences: [...expense.debitedOccurrences, key],
        ),
        previous: expense,
      );
    }
    if (expense.isDebited) return expense;
    return updateExpense(expense.copyWith(isDebited: true), previous: expense);
  }

  Future<Expense> unmarkOccurrenceDebited(
    Expense expense,
    DateTime date,
  ) async {
    if (expense.isRecurring) {
      final key = Expense.isoDate(date);
      if (!expense.debitedOccurrences.contains(key)) return expense;
      return updateExpense(
        expense.copyWith(
          debitedOccurrences: expense.debitedOccurrences
              .where((k) => k != key)
              .toList(),
        ),
        previous: expense,
      );
    }
    if (!expense.isDebited) return expense;
    return updateExpense(expense.copyWith(isDebited: false), previous: expense);
  }

  Future<Expense> toggleOccurrenceDebited(
    Expense expense,
    DateTime date,
  ) async {
    final result = expense.isDebitedAt(date)
        ? await unmarkOccurrenceDebited(expense, date)
        : await markOccurrenceDebited(expense, date);
    AnalyticsService.instance.track('expense_toggled_debited');
    return result;
  }
}

/// Internal period cache. It deliberately stays private to ExpensesService so
/// cache policy does not become another public service dependency.
class _ExpensePeriodData {
  final Map<String, List<Expense>> _cache = {};
  final Map<String, Future<List<Expense>>> _inFlight = {};

  /// Ids of expenses created locally but not yet acknowledged by a server
  /// refresh. They are protected from being dropped by stale snapshots.
  final Set<String> _optimisticIds = {};

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

  /// Merges a server snapshot with unconfirmed optimistic creations so a
  /// freshly created expense survives a refresh that returns stale data.
  ///
  /// Once the server acknowledges an id it is no longer protected, so a
  /// deletion performed on another device still propagates server-side.
  List<Expense> mergeServer(String key, List<Expense> serverExpenses) {
    for (final expense in serverExpenses) {
      if (expense.id != null) _optimisticIds.remove(expense.id);
    }
    if (_optimisticIds.isEmpty) {
      return List<Expense>.from(serverExpenses);
    }

    final existing = _cache[key];
    if (existing == null || existing.isEmpty) {
      return List<Expense>.from(serverExpenses);
    }

    final serverIds = serverExpenses
        .map((expense) => expense.id)
        .whereType<String>()
        .toSet();
    return List<Expense>.from([
      ...serverExpenses,
      ...existing.where(
        (expense) =>
            expense.id != null &&
            _optimisticIds.contains(expense.id) &&
            !serverIds.contains(expense.id),
      ),
    ]);
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
    // If the other account/period caches were not loaded, they stay null
    // and will be populated on next load from Firestore cache.
    if (oldAccountId != newAccountId) {
      // Also ensure the old account's new period is cleared if it was same as new period but different account
    }
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
    _optimisticIds.clear();
  }
}
