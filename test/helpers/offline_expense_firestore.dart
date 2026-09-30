import 'dart:async';

import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// In-memory [ExpenseFirestore] that reproduces how the *real* Cloud Firestore
/// SDK behaves offline, which the older "throw StateError('offline')" fakes did
/// not:
///
/// * a write is applied to the **local cache immediately**;
/// * the Future returned by the write **stays pending until the server
///   acknowledges it** (it never completes while [online] is `false`);
/// * a `Source.server` read fails while offline, while cache reads keep
///   working and include pending local writes.
///
/// Set [rejectWrites] to make the server refuse writes when they are
/// acknowledged (security rules, document deleted elsewhere, ...): the local
/// change is reverted and the write reports failure, like the SDK does.
class OfflineAwareExpenseFirestore extends ExpenseFirestore {
  bool online = false;
  bool rejectWrites = false;

  /// Acknowledged server state.
  final List<Expense> server = [];

  /// Local cache: server state plus not-yet-acknowledged writes.
  final List<Expense> local = [];

  final List<_PendingWrite> _pending = [];

  int get pendingWriteCount => _pending.length;

  /// Simulates the network coming back: pending writes are acknowledged in
  /// order and their Futures complete.
  void goOnline() {
    online = true;
    final writes = List<_PendingWrite>.of(_pending);
    _pending.clear();
    for (final write in writes) {
      write.acknowledge();
    }
  }

  Future<T> _write<T>({
    required void Function(List<Expense> target) apply,
    required T success,
    required T Function() onRejected,
  }) {
    apply(local);
    if (online) return _acknowledge(apply, success, onRejected);

    final completer = Completer<T>();
    _pending.add(
      _PendingWrite(() {
        _acknowledge(
          apply,
          success,
          onRejected,
        ).then(completer.complete, onError: completer.completeError);
      }),
    );
    return completer.future;
  }

  Future<T> _acknowledge<T>(
    void Function(List<Expense> target) apply,
    T success,
    T Function() onRejected,
  ) async {
    if (rejectWrites) {
      // The SDK reverts the optimistic local write when the server refuses it.
      local
        ..clear()
        ..addAll(server);
      return onRejected();
    }
    apply(server);
    return success;
  }

  static void _upsert(List<Expense> target, Expense expense) {
    target.removeWhere((item) => item.id == expense.id);
    target.add(expense);
  }

  @override
  Future<Expense?> create(Expense expense) => _write<Expense?>(
    apply: (target) => _upsert(target, expense),
    success: expense,
    onRejected: () => throw StateError('write rejected'),
  );

  @override
  Future<bool> update(Expense expense) => _write<bool>(
    apply: (target) => _upsert(target, expense),
    success: true,
    onRejected: () => false,
  );

  @override
  Future<bool> delete(String expenseId) => _write<bool>(
    apply: (target) => target.removeWhere((item) => item.id == expenseId),
    success: true,
    onRejected: () => false,
  );

  @override
  Future<Expense?> splitRecurringExpense({
    required Expense previous,
    required Expense next,
  }) => _write<Expense?>(
    apply: (target) {
      _upsert(target, previous);
      _upsert(target, next);
    },
    success: next,
    onRejected: () => null,
  );

  List<Expense> _read(Source source) {
    if (source == Source.server && !online) {
      throw StateError('client is offline');
    }
    return source == Source.server ? server : local;
  }

  @override
  Future<List<Expense>> listByAccountAndPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    Source source = Source.server,
  }) async => _read(source)
      .where(
        (expense) =>
            expense.accountId == accountId &&
            (categoryId == null || expense.categoryId == categoryId) &&
            (expense.isRecurring
                ? expense.debitDate.isBefore(period.startOfNextMonth)
                : period.contains(expense.debitDate)),
      )
      .toList();

  @override
  Future<List<Expense>> listByAccountId(
    String accountId, {
    Source source = Source.server,
  }) async =>
      _read(source).where((expense) => expense.accountId == accountId).toList();
}

class _PendingWrite {
  _PendingWrite(this.acknowledge);

  final void Function() acknowledge;
}
