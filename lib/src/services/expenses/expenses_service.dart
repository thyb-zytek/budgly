import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence_exception.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/calculators/recurring_expense_versioning.dart';
import 'package:budgly/src/services/expenses/expense_period_cache.dart';
import 'package:budgly/src/services/expenses/expense_sync_handler.dart';
import 'package:budgly/src/services/expenses/recurring_expense_persistence.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:budgly/src/services/offline/offline_id.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart' show PendingSync;

class ExpensesService {
  final ExpenseFirestore _expenseFirestore;
  final RecurringExpenseVersioning _recurringVersioning;
  final _periodData = ExpensePeriodCache();
  final AnalyticsService _analytics;
  late final ExpenseSyncHandler _syncHandler;
  late final RecurringExpensePersistence _recurringPersistence;
  final _rejectedWrites = StreamController<String>.broadcast();

  ExpensesService({
    ExpenseFirestore? expenseFirestore,
    RecurringExpenseVersioning? recurringVersioning,
    required this._analytics,
  }) : _expenseFirestore = expenseFirestore ?? ExpenseFirestore(),
       _recurringVersioning =
           recurringVersioning ?? const RecurringExpenseVersioning() {
    _syncHandler = ExpenseSyncHandler(
      firestore: _expenseFirestore,
      periodData: _periodData,
      analytics: _analytics,
      onWriteRejected: _handleRejectedWrite,
    );
    _recurringPersistence = RecurringExpensePersistence(
      firestore: _expenseFirestore,
      periodData: _periodData,
      onWriteRejected: _handleRejectedWrite,
    );
  }

  /// Account ids whose optimistic expense state was invalidated because
  /// Firestore rejected a write asynchronously. Listeners (the session) should
  /// reload the account to show the server truth.
  Stream<String> get rejectedWrites => _rejectedWrites.stream;

  void _handleRejectedWrite(String accountId) {
    _periodData.removeAccount(accountId);
    if (!_rejectedWrites.isClosed) _rejectedWrites.add(accountId);
  }

  /// Closes [rejectedWrites]. The provider is `keepAlive`, so this only
  /// matters for tests that create more than one instance.
  void dispose() {
    unawaited(_rejectedWrites.close());
  }

  /// Registers the drain for expense operations queued by older builds. New
  /// writes never use the application queue (see [ExpenseSyncHandler]).
  void registerSyncHandler(SyncManager manager) {
    manager.registerHandler('expenses', _handlePendingSync);
  }

  void invalidateCache() {
    _periodData.clear();
  }

  /// Cache-first load (RL-01 §3.2). When Firestore's local cache already has
  /// data, it is returned immediately and a background server revalidation
  /// is kicked off; [onRevalidated] is called with the reconciled result once
  /// that revalidation completes, so the caller (`ExpensesSession`, watched
  /// by `PeriodExpenses`/Overview) can push the fresher data into the
  /// reactive session and let the UI rebuild instead of the merge staying
  /// trapped in this service's private `_periodData` cache forever.
  Future<List<Expense>> listExpensesForPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    bool forceRefresh = false,
    void Function(List<Expense>)? onRevalidated,
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
              onRevalidated: onRevalidated,
            ),
          );
          return List.unmodifiable(cached);
        }

        // Cache vide : on NE retourne PAS la liste vide, on attend le serveur.
        // Cela évite d'afficher un état vide au premier lancement.
      } on FirebaseException catch (e) {
        // The local cache can be empty on the first launch. In that case the
        // server is needed to obtain the initial dataset.
        if (e.code != 'failed-precondition' && e.code != 'unavailable') {
          rethrow;
        }
      }
    }

    // Either an explicit refresh, or an empty/unavailable local cache.
    //
    // Only an explicit refresh insists on the server. When the cache was merely
    // empty (a month without expenses is perfectly normal) the default source
    // is used: online it returns the server data, offline it answers from the
    // local cache at once instead of waiting for the network timeout.
    final existing = _periodData.inFlight(key);
    if (existing != null) return existing;

    final future = _refreshPeriod(
      accountId,
      period,
      categoryId: categoryId,
      key: key,
      source: forceRefresh ? Source.server : Source.serverAndCache,
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
    void Function(List<Expense>)? onRevalidated,
  }) async {
    try {
      final merged = await _refreshPeriod(
        accountId,
        period,
        categoryId: categoryId,
        key: key,
      );
      onRevalidated?.call(merged);
    } catch (e) {
      AppLogger.debug('Background expense refresh unavailable: $e');
    }
  }

  Future<List<Expense>> _refreshPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    required String key,
    Source source = Source.server,
  }) async {
    try {
      final expenses = await _expenseFirestore.listByAccountAndPeriod(
        accountId,
        period,
        categoryId: categoryId,
        source: source,
      );
      // A server snapshot can still be stale while an optimistic create is
      // being persisted (offline replay or slow network). Never let it drop
      // locally-created expenses that the server has not acknowledged yet:
      // keep the unconfirmed ones until the server returns them.
      final merged = _periodData.mergeServer(key, expenses);
      // The server has now returned these expenses, so they are acknowledged:
      // release their optimistic shield so a later server-side deletion still
      // propagates. Only a genuine server answer proves an acknowledgement: a
      // cache-served result also contains our own pending local writes.
      if (source == Source.server) _periodData.releaseConfirmed(expenses);
      _periodData.put(key, merged);
      // Keep the store in sync with everything locally known about the
      // account so optimistic fallbacks and repeat lookups (e.g. after a
      // recurring occurrence delete) see these expenses too.
      return List.unmodifiable(merged);
    } catch (e) {
      _analytics.track('expense_load_failed', {'error': e.toString()});
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
  }) async {
    final page = await _expenseFirestore
        .listByCategoryAndPeriodPage(
          accountId,
          categoryId,
          period,
          limit: limit,
          startAfter: startAfter,
          includeRecurring: includeRecurring,
        )
        .timeout(AppConstants.networkTimeout);
    return page;
  }

  Future<Expense> createExpense(Expense expense) async {
    final optimistic = expense.id == null
        ? expense.copyWith(id: OfflineId.uuid())
        : expense;
    final periodKey =
        '${optimistic.accountId}|${Period.fromDate(optimistic.debitDate)}|*';
    if (optimistic.isRecurring) {
      // A recurring series projects into every covered period. The debit-date
      // period below keeps its cache with the optimistic expense; every other
      // already-cached period must be reloaded on its next visit.
      _periodData.removeAccountExcept(optimistic.accountId, periodKey);
    }
    final cachedPeriod = _periodData.ensure(periodKey);
    cachedPeriod.add(optimistic);
    cachedPeriod.sort((a, b) => b.debitDate.compareTo(a.debitDate));
    _periodData.addOptimistic(optimistic.id!);
    _periodData.markPending(optimistic.id!, optimistic);
    _syncHandler.create(optimistic);
    _analytics.track('expense_created', {'recurring': optimistic.isRecurring});
    return optimistic;
  }

  Future<Expense> updateRecurringExpenseFromOccurrence({
    required Expense original,
    required Expense updated,
    required DateTime effectiveDate,
  }) async {
    _analytics.track('recurring_expense_version_changed');
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
    return resolved;
  }

  Future<Expense> updateExpense(Expense expense, {Expense? previous}) async {
    if (previous != null) {
      _periodData.optimisticUpdateExpense(previous, expense);
    } else {
      _periodData.removeAccount(expense.accountId);
    }
    _periodData.markPending(expense.id!, expense);
    // The period cache may not hold the expense yet (e.g. it was only loaded into the
    // period cache), in which case _store.updateExpense is a silent no-op.
    _syncHandler.update(expense);
    _analytics.track('expense_updated', {'recurring': expense.isRecurring});
    return expense;
  }

  Future<bool> deleteExpense(String expenseId, String accountId) async {
    final deletedExpense = _periodData.findById(expenseId);
    _periodData.removeAccount(accountId);
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
    _analytics.track('expense_deleted');

    // Not awaited: offline, the Firestore delete only completes once the
    // server acknowledges it. The write is durable in Firestore's own queue.
    _syncHandler.delete(expenseId, accountId: accountId);
    if (deletedExpense != null) {
      _periodData.ensure(
        _periodData.key(
          deletedExpense.accountId,
          Period.fromDate(deletedExpense.debitDate),
          null,
        ),
      );
    }
    return true;
  }

  Future<Expense> modifySingleOccurrence({
    required Expense original,
    required DateTime occurrenceDate,
    required Expense override,
  }) async {
    if (!original.isRecurring || original.id == null) {
      return updateExpense(override, previous: original);
    }

    final key = '${original.id}@${Expense.isoDate(occurrenceDate)}';
    ExpenseOccurrenceException? existing;
    for (final item in original.occurrenceExceptions) {
      if (item.key == key) {
        existing = item;
        break;
      }
    }
    final exception = ExpenseOccurrenceException(
      key: key,
      amount: override.amount,
      name: override.name,
      categoryId: override.categoryId,
      debitDate: existing?.debitDate,
      deleted: existing?.deleted ?? false,
      isDebited: original.isDebitedAt(occurrenceDate),
    );
    final exceptions = [
      for (final item in original.occurrenceExceptions)
        if (item.key != key) item,
      exception,
    ];
    final updated = original.copyWith(occurrenceExceptions: exceptions);
    await updateExpense(updated, previous: original);
    _analytics.track('recurring_expense_occurrence_modified');
    return updated;
  }

  Future<Expense> modifyFutureOccurrences({
    required Expense original,
    required DateTime effectiveDate,
    required Expense updated,
  }) {
    return updateRecurringExpenseFromOccurrence(
      original: original,
      updated: updated,
      effectiveDate: effectiveDate,
    );
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
    final targetKey = '${expense.id}@${Expense.isoDate(targetDay)}';
    final exception = ExpenseOccurrenceException(
      key: targetKey,
      deleted: true,
      isDebited: expense.isDebitedAt(targetDay),
    );
    final updated = expense.copyWith(
      occurrenceExceptions: [
        for (final item in expense.occurrenceExceptions)
          if (item.key != targetKey) item,
        exception,
      ],
    );
    await updateExpense(updated, previous: expense);
    _analytics.track('expense_single_occurrence_deleted');
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
      occurrenceExceptions: [
        for (final exception in expense.occurrenceExceptions)
          if (_exceptionSourceDate(exception).isBefore(targetDay) &&
              (exception.debitDate == null ||
                  exception.debitDate!.isBefore(targetDay)))
            exception,
      ],
    );
    await updateExpense(updated, previous: expense);
    _analytics.track('expense_future_occurrences_deleted');
    return true;
  }

  DateTime _exceptionSourceDate(ExpenseOccurrenceException exception) =>
      DateTime.parse(
        exception.key.substring(exception.key.lastIndexOf('@') + 1),
      );

  Future<void> _handlePendingSync(PendingSync operation) =>
      _syncHandler.handlePendingSync(operation);

  Expense? getExpenseById(String expenseId) => _periodData.findById(expenseId);

  List<Expense> getExpensesForAccount(String accountId) =>
      _periodData.allCachedForAccount(accountId);

  /// Returns every locally cached expense for the account. Offline-first: the
  /// store is populated from Firestore's native cache, so callers never wait
  /// on the network to build period projections such as undebited detection.
  ///
  /// When [forceRefresh] is true, a real server query replaces the local
  /// snapshot so the caller sees the authoritative account state (e.g. the
  /// undebited banner at launch and on pull-to-refresh). Offline, the query
  /// fails and the local store is served instead.
  ///
  /// The forced read is deliberately non-mutating: it must not clobber the
  /// shared store or notify listeners, otherwise a concurrent optimistic
  /// mutation could be reverted by the server snapshot.
  Future<List<Expense>> listExpensesForAccountBefore(
    String accountId,
    DateTime endExclusive, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      return getExpensesForAccount(accountId)
          .where((expense) => expense.debitDate.isBefore(endExclusive))
          .toList(growable: false);
    }
    try {
      final serverExpenses = await _expenseFirestore.listByAccountBefore(
        accountId,
        endExclusive,
      );
      final serverIds = <String>{
        for (final expense in serverExpenses)
          if (expense.id != null) expense.id!,
      };
      final merged = <Expense>[
        for (final expense in serverExpenses)
          if (!_periodData.isPendingDelete(expense.id)) expense,
        for (final pending in _periodData.pendingForAccount(accountId))
          if (!serverIds.contains(pending.id) &&
              pending.debitDate.isBefore(endExclusive))
            pending,
      ]..sort((a, b) => b.debitDate.compareTo(a.debitDate));
      return List.unmodifiable(merged);
    } catch (e) {
      _analytics.track('expense_load_failed', {'error': e.toString()});
      return getExpensesForAccount(accountId)
          .where((expense) => expense.debitDate.isBefore(endExclusive))
          .toList(growable: false);
    }
  }

  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) return getExpensesForAccount(accountId);
    try {
      final serverExpenses = await _expenseFirestore.listByAccountId(accountId);
      final serverIds = <String>{
        for (final expense in serverExpenses)
          if (expense.id != null) expense.id!,
      };
      // Merge with unconfirmed local mutations so a slow sync never drops a
      // just-created/updated expense the server has not returned yet.
      final merged = <Expense>[
        for (final expense in serverExpenses)
          if (!_periodData.isPendingDelete(expense.id)) expense,
        for (final pending in _periodData.pendingForAccount(accountId))
          if (!serverIds.contains(pending.id)) pending,
      ]..sort((a, b) => b.debitDate.compareTo(a.debitDate));
      return List.unmodifiable(merged);
    } catch (e) {
      _analytics.track('expense_load_failed', {'error': e.toString()});
      // Offline fallback: the period cache remains the source of truth.
      return getExpensesForAccount(accountId);
    }
  }

  /// Immediate, local best-effort removal (what the cache knows about). It
  /// hands the batch to Firestore's own durable queue and never waits for the
  /// server, so it cannot freeze an offline caller. Documents this device never
  /// cached are removed by the durable [purgeByAccountId] cleanup.
  Future<void> deleteByAccountId(String accountId) async {
    try {
      await _expenseFirestore.deleteByAccountId(accountId, awaitAck: false);
    } catch (e) {
      AppLogger.debug('Local expense removal unavailable: $e');
    }
  }

  /// See [deleteByAccountId].
  Future<void> deleteByCategoryId(String categoryId) async {
    try {
      await _expenseFirestore.deleteByCategoryId(categoryId, awaitAck: false);
    } catch (e) {
      AppLogger.debug('Local expense removal unavailable: $e');
    }
  }

  /// Server-side removal used by the durable cleanup: it queries the server
  /// (so uncached documents are found) and throws when it cannot, so the
  /// caller retries instead of silently leaving orphans.
  Future<void> purgeByAccountId(String accountId) =>
      _expenseFirestore.deleteByAccountId(accountId, source: Source.server);

  /// See [purgeByAccountId].
  Future<void> purgeByCategoryId(String categoryId) =>
      _expenseFirestore.deleteByCategoryId(categoryId, source: Source.server);

  Future<Expense> moveOccurrenceToDate(
    Expense expense,
    DateTime occurrenceDate,
    DateTime targetDate, {
    required bool markDebited,
  }) async {
    if (!expense.isRecurring) {
      final updated = expense.copyWith(
        debitDate: targetDate,
        isDebited: markDebited,
      );
      return updateExpense(updated, previous: expense);
    }

    final sourceDay = DateTime(
      occurrenceDate.year,
      occurrenceDate.month,
      occurrenceDate.day,
    );
    final key = '${expense.id}@${Expense.isoDate(sourceDay)}';
    ExpenseOccurrenceException? existing;
    for (final item in expense.occurrenceExceptions) {
      if (item.key == key) {
        existing = item;
        break;
      }
    }
    final exceptions = [
      for (final item in expense.occurrenceExceptions)
        if (item.key != key) item,
      ExpenseOccurrenceException(
        key: key,
        amount: existing?.amount,
        name: existing?.name,
        categoryId: existing?.categoryId,
        debitDate: DateTime(targetDate.year, targetDate.month, targetDate.day),
        deleted: existing?.deleted ?? false,
        isDebited: markDebited,
      ),
    ];
    final updated = expense.copyWith(occurrenceExceptions: exceptions);
    await updateExpense(updated, previous: expense);
    return updated;
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
    _analytics.track('expense_toggled_debited');
    return result;
  }
}
