import 'dart:async';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/expenses/expense_period_cache.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';

import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';

/// Owns persistence/retry mechanics for expense mutations.
///
/// It deliberately knows nothing about presentation or ViewModels. The
/// ExpensesService remains the public orchestrator while this class isolates
/// the network/offline boundary.
class ExpenseSyncHandler {
  final ExpenseFirestore _firestore;
  final ExpensePeriodCache _periodData;
  final SyncQueue _syncQueue;
  final Future<void> Function() _flushSync;

  ExpenseSyncHandler({
    required this._firestore,
    required this._periodData,
    SyncQueue? syncQueue,
    Future<void> Function()? flushSync,
  }) : _syncQueue = syncQueue ?? SyncQueue.instance,
       _flushSync = flushSync ?? (() => SyncManager.instance.flush());

  Future<void> persistCreate(Expense expense) async {
    try {
      final created = await _firestore.create(expense);
      if (created == null) throw StateError('Failed to create expense');
      // The optimistic shield is intentionally kept here. Firestore queues
      // offline writes locally, so a server query can still lag behind the
      // local write; releasing the shield now would let a stale refresh drop
      // the just-created expense. It is released once the server confirms the
      // expense in a refresh (see ExpensePeriodCache.releaseConfirmed).
    } catch (e, stackTrace) {
      AnalyticsService.instance.track(
        'expense_create_failed',
        {'error': e.toString()},
      );
      AppLogger.error('Failed to persist expense creation', e, stackTrace);
      await queueMutation(
        id: 'expense:create:${expense.id}',
        operation: 'create',
        expense: expense,
      );
    }
  }

  Future<void> persistUpdate(Expense expense) async {
    try {
      final success = await _firestore.update(expense);
      if (!success) throw StateError('Failed to update expense');
      _periodData.clearPending(expense.id);
    } catch (e, stackTrace) {
      AnalyticsService.instance.track(
        'expense_update_failed',
        {'error': e.toString()},
      );
      AppLogger.error('Failed to update expense', e, stackTrace);
      await queueMutation(
        id: 'expense:update:${expense.id}',
        operation: 'update',
        expense: expense,
      );
    }
  }

  Future<bool> delete(String expenseId) async {
    try {
      final success = await _firestore.delete(expenseId);
      if (!success) throw StateError('Failed to delete expense');
      _periodData.clearPending(expenseId);
      return true;
    } catch (e, stackTrace) {
      AnalyticsService.instance.track(
        'expense_delete_failed',
        {'error': e.toString()},
      );
      AppLogger.error('Failed to delete expense', e, stackTrace);
      await queueMutation(
        id: 'expense:delete:$expenseId',
        operation: 'delete',
        rawPayload: {'id': expenseId},
      );
      return true;
    }
  }

  Future<void> queueMutation({
    required String id,
    required String operation,
    Expense? expense,
    Map<String, dynamic>? rawPayload,
  }) async {
    final payload = rawPayload ?? expense?.toJson();
    if (payload == null) return;
    await _syncQueue.enqueue(
      id: id,
      type: 'expenses',
      operation: operation,
      payload: payload,
    );
    unawaited(_flushSync());
  }

  Future<void> handlePendingSync(PendingSync operation) async {
    switch (operation.operation) {
      case 'create':
        final expense = Expense.fromJson(operation.payload);
        final created = await _firestore.create(expense);
        if (created == null) throw StateError('Failed to create expense');
        // Same rationale as persistCreate: keep the shield until the server
        // confirms the expense in a refresh query.
      case 'update':
        final expense = Expense.fromJson(operation.payload);
        final success = await _firestore.update(expense);
        if (!success) throw StateError('Failed to update expense');
        _periodData.clearPending(expense.id);
      case 'delete':
        final id = operation.payload['id'].toString();
        final success = await _firestore.delete(id);
        if (!success) throw StateError('Failed to delete expense');
        _periodData.clearPending(id);
      default:
        throw StateError('Unknown expense sync operation: ${operation.operation}');
    }
  }
}
