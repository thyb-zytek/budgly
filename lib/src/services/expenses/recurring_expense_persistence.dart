import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/expenses/expense_period_cache.dart';
import 'package:budgly/src/services/offline/offline_id.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';

/// Persists a recurring-series split and falls back to the application sync
/// queue when Firestore cannot commit it immediately.
///
/// The caller owns the local projection/store update. This class only owns the
/// persistence boundary and returns the identity that should be projected.
class RecurringExpensePersistence {
  final ExpenseFirestore _firestore;
  final ExpensePeriodCache _periodData;
  final SyncQueue _syncQueue;
  final Duration _timeout;
  final Future<void> Function() _flushSync;

  RecurringExpensePersistence({
    required this._firestore,
    required this._periodData,
    SyncQueue? syncQueue,
    this._timeout = const Duration(seconds: 5),
    Future<void> Function()? flushSync,
  }) : _syncQueue = syncQueue ?? SyncQueue.instance,
       _flushSync = flushSync ?? (() => SyncManager.instance.flush());

  Future<Expense> split({
    required Expense previous,
    required Expense next,
  }) async {
    if (previous.id == null) {
      throw StateError('Cannot split a recurring expense without an id');
    }

    Expense resolved;
    var queued = false;
    try {
      final created = await _firestore
          .splitRecurringExpense(previous: previous, next: next)
          .timeout(_timeout);
      if (created == null) {
        resolved = next.copyWith(id: OfflineId.uuid());
        queued = true;
      } else {
        resolved = created;
      }
    } catch (e, stackTrace) {
      resolved = next.copyWith(id: OfflineId.uuid());
      queued = true;
      AppLogger.error('Failed to persist recurring expense split', e, stackTrace);
    }

    if (queued) {
      await _queueSplit(previous: previous, next: resolved);
    }

    return resolved;
  }

  Future<void> _queueSplit({
    required Expense previous,
    required Expense next,
  }) async {
    _periodData.markPending(previous.id!, previous);
    _periodData.markPending(next.id!, next);

    await _syncQueue.enqueue(
      id: 'expense:update:${previous.id}',
      type: 'expenses',
      operation: 'update',
      payload: previous.toJson(),
    );
    await _syncQueue.enqueue(
      id: 'expense:create:${next.id}',
      type: 'expenses',
      operation: 'create',
      payload: next.toJson(),
    );
    await _flushSync();
  }
}
