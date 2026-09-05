import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/calculators/recurring_expense_versioning.dart';
import 'package:budgly/src/services/expenses/expense_period_cache.dart';
import 'package:budgly/src/services/expenses/expense_sync_handler.dart';
import 'package:budgly/src/services/expenses/recurring_expense_persistence.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:budgly/src/services/offline/offline_id.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
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
  final _periodData = ExpensePeriodCache();
  late final ExpenseSyncHandler _syncHandler;
  late final RecurringExpensePersistence _recurringPersistence;

  ExpensesService({
    ExpenseFirestore? expenseFirestore,
    ExpensesStore? store,
    RecurringExpenseVersioning? recurringVersioning,
  }) : _expenseFirestore = expenseFirestore ?? ExpenseFirestore(),
       _store = store ?? ExpensesStore.instance,
       _recurringVersioning =
           recurringVersioning ?? const RecurringExpenseVersioning() {
    _syncHandler = ExpenseSyncHandler(
      firestore: _expenseFirestore,
      periodData: _periodData,
    );
    _recurringPersistence = RecurringExpensePersistence(
      firestore: _expenseFirestore,
      periodData: _periodData,
    );
    _store.addListener(notifyListeners);
    SyncManager.instance.registerHandler('expenses', _handlePendingSync);
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
      // The server has now returned these expenses, so they are acknowledged:
      // release their optimistic shield so a later server-side deletion still
      // propagates.
      _periodData.releaseConfirmed(expenses);
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
    _periodData.markPending(optimistic.id!, optimistic);
    _store.addExpense(optimistic);
    notifyListeners();
    unawaited(_persistCreatedExpense(optimistic));
    AnalyticsService.instance.track('expense_created', {
      'recurring': optimistic.isRecurring,
    });
    return optimistic;
  }

  Future<void> _persistCreatedExpense(Expense expense) =>
      _syncHandler.persistCreate(expense);

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

    final resolved = await _recurringPersistence.split(
      previous: version.previous,
      next: version.next,
    );

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
    _periodData.markPending(expense.id!, expense);
    unawaited(_persistExpenseUpdate(expense));
    AnalyticsService.instance.track('expense_updated', {
      'recurring': expense.isRecurring,
    });
    return expense;
  }

  Future<void> _persistExpenseUpdate(Expense expense) =>
      _syncHandler.persistUpdate(expense);

  Future<bool> deleteExpense(String expenseId, String accountId) async {
    final deletedExpense = _store.getExpenseById(expenseId);
    _periodData.removeAccount(accountId);
    _store.removeExpense(expenseId, accountId);
    _periodData.markPendingDelete(expenseId);
    if (deletedExpense != null) {
      _periodData.ensure(
        _periodData.key(
          deletedExpense.accountId,
          Period.fromDate(deletedExpense.debitDate),
          null,
        ),
      );
    }
    AnalyticsService.instance.track('expense_deleted');

    final result = await _syncHandler.delete(expenseId);
    if (deletedExpense != null) {
      _periodData.ensure(
        _periodData.key(
          deletedExpense.accountId,
          Period.fromDate(deletedExpense.debitDate),
          null,
        ),
      );
    }
    return result;
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

    final resolvedNext = await _recurringPersistence.split(
      previous: previous,
      next: next,
    );
    _periodData.removeAccount(expense.accountId);
    _store.replaceExpenseWithVersions(
      previous: previous,
      next: resolvedNext,
    );
    AnalyticsService.instance.track('expense_single_occurrence_deleted');
    return true;
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

  Future<void> _handlePendingSync(PendingSync operation) =>
      _syncHandler.handlePendingSync(operation);

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
