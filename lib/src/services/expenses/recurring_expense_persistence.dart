import 'dart:async';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/expenses/expense_period_cache.dart';
import 'package:budgly/src/services/offline/offline_id.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';

/// Persists a recurring-series split (update of the previous version + create
/// of the next one) as a single Firestore batch.
///
/// The batch is atomic and durable through Firestore's own offline queue, so
/// there is deliberately no application-queue fallback: replaying the two
/// halves as independent operations would break atomicity. Like every
/// Firestore write, the commit is not awaited (it only completes on a server
/// acknowledgement, which never happens offline); a rejection is reported
/// through [onWriteRejected].
///
/// The caller owns the local projection/store update. This class only owns the
/// persistence boundary and returns the identity that should be projected.
class RecurringExpensePersistence {
  final ExpenseFirestore _firestore;
  final ExpensePeriodCache _periodData;
  final void Function(String accountId) _onWriteRejected;

  RecurringExpensePersistence({
    required this._firestore,
    required this._periodData,
    required this._onWriteRejected,
  });

  Future<Expense> split({
    required Expense previous,
    required Expense next,
  }) async {
    if (previous.id == null) {
      throw StateError('Cannot split a recurring expense without an id');
    }

    // Allocate the identity before the commit so the local projection and the
    // batch always agree on the id of the next version.
    final resolved = next.id == null
        ? next.copyWith(id: OfflineId.uuid())
        : next;

    _periodData.markPending(previous.id!, previous);
    _periodData.markPending(resolved.id!, resolved);

    unawaited(_commit(previous: previous, next: resolved));
    return resolved;
  }

  Future<void> _commit({
    required Expense previous,
    required Expense next,
  }) async {
    try {
      final created = await _firestore.splitRecurringExpense(
        previous: previous,
        next: next,
      );
      if (created == null) throw StateError('Recurring split was rejected');
      _periodData.clearPending(previous.id);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to persist recurring expense split',
        e,
        stackTrace,
      );
      _periodData.clearPending(previous.id);
      _periodData.clearPending(next.id);
      _onWriteRejected(previous.accountId);
    }
  }
}
