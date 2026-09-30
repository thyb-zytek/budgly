import 'dart:async';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/expenses/expense_period_cache.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';

/// Owns the Firestore write boundary for expense mutations.
///
/// **Single durable queue.** Firestore's native offline persistence is the only
/// queue for expense writes: a `set/update/delete/commit` is applied to the
/// local cache immediately and replayed by the SDK when the network returns.
/// The application `SyncQueue` is deliberately *not* used as a second queue
/// (two queues for the same document could replay a stale version over a newer
/// one, and could split an atomic batch).
///
/// **Never await the write.** The Future returned by a Firestore write only
/// completes once the *server* acknowledges it, so offline it stays pending
/// until connectivity returns. Awaiting it would freeze the caller. These
/// methods therefore return immediately; a *rejection* (security rules, a
/// document deleted elsewhere, ...) arrives asynchronously, drops the
/// optimistic state and asks the owner to reconcile through [onWriteRejected].
///
/// It knows nothing about presentation or ViewModels.
class ExpenseSyncHandler {
  final ExpenseFirestore _firestore;
  final ExpensePeriodCache _periodData;
  final AnalyticsService _analytics;
  final void Function(String accountId) _onWriteRejected;

  ExpenseSyncHandler({
    required this._firestore,
    required this._periodData,
    required this._analytics,
    required this._onWriteRejected,
  });

  void create(Expense expense) => _write(
    event: 'expense_create_failed',
    accountId: expense.accountId,
    expenseId: expense.id,
    action: () async {
      final created = await _firestore.create(expense);
      if (created == null) throw StateError('Failed to create expense');
      // The optimistic shield is intentionally kept here. A server query
      // can still lag behind the local write; it is released once a
      // refresh returns the expense (ExpensePeriodCache.releaseConfirmed).
    },
  );

  void update(Expense expense) => _write(
    event: 'expense_update_failed',
    accountId: expense.accountId,
    expenseId: expense.id,
    action: () async {
      final success = await _firestore.update(expense);
      if (!success) throw StateError('Failed to update expense');
      _periodData.clearPending(expense.id);
    },
  );

  void delete(String expenseId, {required String accountId}) => _write(
    event: 'expense_delete_failed',
    accountId: accountId,
    expenseId: expenseId,
    action: () async {
      final success = await _firestore.delete(expenseId);
      if (!success) throw StateError('Failed to delete expense');
      _periodData.clearPending(expenseId);
    },
  );

  /// Runs [action] without blocking the caller (see the class comment).
  void _write({
    required String event,
    required String accountId,
    required String? expenseId,
    required Future<void> Function() action,
  }) {
    unawaited(_reconcileOnRejection(event, accountId, expenseId, action));
  }

  Future<void> _reconcileOnRejection(
    String event,
    String accountId,
    String? expenseId,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e, stackTrace) {
      _analytics.track(event, {'error': e.toString()});
      AppLogger.error('Expense write rejected ($event)', e, stackTrace);
      // Firestore already reverted its local copy. Drop the optimistic shield
      // so the next read shows the truth instead of a phantom change.
      _periodData.clearPending(expenseId);
      _onWriteRejected(accountId);
    }
  }

  /// Drains operations queued by builds that still used the application
  /// `SyncQueue` for expenses. Nothing enqueues them any more; this handler
  /// only exists so an upgrade does not strand a user's pending writes.
  ///
  /// A timeout means the write was handed to Firestore's own durable queue
  /// (the SDK Future does not complete offline), so the operation is done.
  Future<void> handlePendingSync(PendingSync operation) async {
    switch (operation.operation) {
      case 'create':
        final expense = Expense.fromJson(operation.payload);
        await _handOff(() async {
          final created = await _firestore.create(expense);
          if (created == null) throw StateError('Failed to create expense');
        });
      case 'update':
        final expense = Expense.fromJson(operation.payload);
        await _handOff(() async {
          final success = await _firestore.update(expense);
          if (!success) throw StateError('Failed to update expense');
          _periodData.clearPending(expense.id);
        });
      case 'delete':
        final id = operation.payload['id'].toString();
        await _handOff(() async {
          final success = await _firestore.delete(id);
          if (!success) throw StateError('Failed to delete expense');
          _periodData.clearPending(id);
        });
      default:
        throw StateError(
          'Unknown expense sync operation: ${operation.operation}',
        );
    }
  }

  Future<void> _handOff(Future<void> Function() write) async {
    try {
      await write().timeout(AppConstants.networkTimeout);
    } on TimeoutException {
      // Accepted by Firestore's local queue; it will be delivered natively.
    }
  }
}
