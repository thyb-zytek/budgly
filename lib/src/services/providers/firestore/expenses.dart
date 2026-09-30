import 'dart:async';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:budgly/src/models/budget/period.dart';

class ExpenseFirestore {
  ExpenseFirestore({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreInput = firestore,
      _authInput = auth;

  final FirebaseFirestore? _firestoreInput;
  final FirebaseAuth? _authInput;

  FirebaseFirestore get _firestore =>
      _firestoreInput ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInput ?? FirebaseAuth.instance;

  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_currentUserId).collection('expenses');

  Future<ExpensePage> listByCategoryAndPeriodPage(
    String accountId,
    String categoryId,
    Period period, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    bool includeRecurring = true,
  }) async {
    final start = Timestamp.fromDate(period.startOfMonth);
    final endExclusive = Timestamp.fromDate(period.startOfNextMonth);

    Query<Map<String, dynamic>> oneOffQuery = _collection
        .where('accountId', isEqualTo: accountId)
        .where('categoryId', isEqualTo: categoryId)
        .where('recurrence', isEqualTo: 'none')
        .where('debitDate', isGreaterThanOrEqualTo: start)
        .where('debitDate', isLessThan: endExclusive)
        .orderBy('debitDate', descending: true);
    if (startAfter != null) {
      oneOffQuery = oneOffQuery.startAfterDocument(startAfter);
    }
    oneOffQuery = oneOffQuery.limit(limit);

    final oneOffFuture = oneOffQuery.get();
    final recurringFuture = includeRecurring
        ? _collection
              .where('accountId', isEqualTo: accountId)
              .where('categoryId', isEqualTo: categoryId)
              .where('recurrence', isNotEqualTo: 'none')
              .where('debitDate', isLessThan: endExclusive)
              .get()
        : Future.value(null);

    final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>?>([
      oneOffFuture,
      recurringFuture,
    ]);
    final oneOffSnapshot = results[0]!;
    final recurringSnapshot = results[1];

    final expenses = oneOffSnapshot.docs
        .map((doc) => Expense.fromMap(doc.id, doc.data()))
        .toList();

    if (recurringSnapshot != null) {
      expenses.addAll(
        recurringSnapshot.docs
            .map((doc) => Expense.fromMap(doc.id, doc.data()))
            .where((expense) {
              final endExclusive = expense.endDateExclusive;
              return expense.debitDate.isBefore(period.startOfNextMonth) &&
                  (endExclusive == null ||
                      endExclusive.isAfter(period.startOfMonth));
            }),
      );
    }

    expenses.sort((a, b) => b.debitDate.compareTo(a.debitDate));
    return ExpensePage(
      expenses: expenses,
      cursor: oneOffSnapshot.docs.isEmpty
          ? startAfter
          : oneOffSnapshot.docs.last,
      hasMore: oneOffSnapshot.docs.length == limit,
    );
  }

  Future<List<Expense>> listByAccountAndPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    Source source = Source.server,
  }) async {
    final start = Timestamp.fromDate(period.startOfMonth);
    final endExclusive = Timestamp.fromDate(period.startOfNextMonth);

    Query<Map<String, dynamic>> oneOffQuery = _collection
        .where('accountId', isEqualTo: accountId)
        .where('recurrence', isEqualTo: 'none')
        .where('debitDate', isGreaterThanOrEqualTo: start)
        .where('debitDate', isLessThan: endExclusive)
        .orderBy('debitDate', descending: true);
    if (categoryId != null) {
      oneOffQuery = oneOffQuery.where('categoryId', isEqualTo: categoryId);
    }

    Query<Map<String, dynamic>> recurringQuery = _collection
        .where('accountId', isEqualTo: accountId)
        .where('recurrence', isNotEqualTo: 'none')
        .where('debitDate', isLessThan: endExclusive);
    // Recurring occurrences can carry a persisted category exception. The
    // base document may therefore belong to another category even though an
    // occurrence is displayed in this one. Keep the recurring query broad and
    // let ExpenseOccurrenceCalculator resolve/filter the effective category.

    final snapshots = await Future.wait([
      oneOffQuery
          .get(GetOptions(source: source))
          .timeout(AppConstants.networkTimeout),
      recurringQuery
          .get(GetOptions(source: source))
          .timeout(AppConstants.networkTimeout),
    ]);

    final expenses = [
      ...snapshots[0].docs.map((doc) => Expense.fromMap(doc.id, doc.data())),
      ...snapshots[1].docs.map((doc) => Expense.fromMap(doc.id, doc.data())),
    ];

    return expenses.where((expense) {
      if (!expense.isRecurring) return true;
      final endExclusive = expense.endDateExclusive;
      return expense.debitDate.isBefore(period.startOfNextMonth) &&
          (endExclusive == null || endExclusive.isAfter(period.startOfMonth));
    }).toList();
  }

  Future<List<Expense>> listByAccountId(
    String accountId, {
    Source source = Source.server,
  }) async {
    final snapshot = await _collection
        .where('accountId', isEqualTo: accountId)
        .orderBy('debitDate', descending: true)
        .get(GetOptions(source: source))
        .timeout(AppConstants.networkTimeout);
    return snapshot.docs
        .map((doc) => Expense.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<Expense>> listByAccountBefore(
    String accountId,
    DateTime endExclusive, {
    Source source = Source.server,
  }) async {
    final snapshot = await _collection
        .where('accountId', isEqualTo: accountId)
        .where('debitDate', isLessThan: Timestamp.fromDate(endExclusive))
        .orderBy('debitDate', descending: true)
        .get(GetOptions(source: source))
        .timeout(AppConstants.networkTimeout);
    return snapshot.docs
        .map((doc) => Expense.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<Expense?> create(Expense expense) async {
    final docRef = expense.id == null
        ? _collection.doc()
        : _collection.doc(expense.id);
    await docRef.set(expense.toCreateMap());

    // Firestore persists the write locally and queues it for the server when
    // offline. Returning the deterministic document id also lets the UI use
    // the same identity immediately instead of waiting for a server roundtrip.
    return expense.copyWith(id: docRef.id);
  }

  Future<Expense?> splitRecurringExpense({
    required Expense previous,
    required Expense next,
  }) async {
    if (previous.id == null) return null;

    try {
      // The next version must have a deterministic identity before the batch
      // is sent. If Firestore accepts the batch but the response is lost, the
      // sync queue can replay the exact same create without producing a second
      // occurrence.
      final nextRef = next.id == null
          ? _collection.doc()
          : _collection.doc(next.id);
      final batch = _firestore.batch();
      batch.update(_collection.doc(previous.id), previous.toUpdateMap());
      batch.set(nextRef, next.toCreateMap());
      await batch.commit();
      return next.copyWith(id: nextRef.id);
    } catch (e) {
      AppLogger.error('Failed to split recurring expense ${previous.id}', e);
      return null;
    }
  }

  Future<bool> update(Expense expense) async {
    if (expense.id == null) return false;
    try {
      await _collection.doc(expense.id).update(expense.toUpdateMap());
      return true;
    } catch (e) {
      AppLogger.error('Failed to update expense ${expense.id}', e);
      return false;
    }
  }

  Future<bool> delete(String expenseId) async {
    try {
      await _collection.doc(expenseId).delete();
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete expense $expenseId', e);
      return false;
    }
  }

  /// Firestore caps a batch at 500 writes.
  static const _batchLimit = 400;

  /// Deletes every expense of [accountId].
  ///
  /// [source] decides which documents are found: `serverAndCache` (default)
  /// answers from the local cache when offline, `server` also finds documents
  /// this device never cached. With [awaitAck] `false` the batch is handed to
  /// Firestore's durable queue and the call returns without waiting for the
  /// server (which never answers while offline).
  Future<void> deleteByAccountId(
    String accountId, {
    Source source = Source.serverAndCache,
    bool awaitAck = true,
  }) =>
      _deleteWhere('accountId', accountId, source: source, awaitAck: awaitAck);

  /// Deletes every expense of [categoryId]; see [deleteByAccountId].
  Future<void> deleteByCategoryId(
    String categoryId, {
    Source source = Source.serverAndCache,
    bool awaitAck = true,
  }) => _deleteWhere(
    'categoryId',
    categoryId,
    source: source,
    awaitAck: awaitAck,
  );

  Future<void> _deleteWhere(
    String field,
    String value, {
    required Source source,
    required bool awaitAck,
  }) async {
    final snapshot = await _collection
        .where(field, isEqualTo: value)
        .get(GetOptions(source: source))
        .timeout(AppConstants.networkTimeout);
    final docs = snapshot.docs;
    for (var start = 0; start < docs.length; start += _batchLimit) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(start).take(_batchLimit)) {
        batch.delete(doc.reference);
      }
      final commit = batch.commit();
      if (awaitAck) {
        try {
          await commit.timeout(AppConstants.networkTimeout);
        } on TimeoutException {
          // Accepted by Firestore's local queue; delivered natively later.
        }
      } else {
        unawaited(
          commit.catchError((Object e) {
            AppLogger.debug('Expense batch deletion rejected: $e');
          }),
        );
      }
    }
  }
}
