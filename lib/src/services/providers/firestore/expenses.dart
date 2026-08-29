import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:budgly/src/models/budget/period.dart';

class ExpenseFirestore {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
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
    final end = Timestamp.fromDate(period.endOfMonth);

    Query<Map<String, dynamic>> oneOffQuery = _collection
        .where('accountId', isEqualTo: accountId)
        .where('categoryId', isEqualTo: categoryId)
        .where('recurrence', isEqualTo: 'none')
        .where('debitDate', isGreaterThanOrEqualTo: start)
        .where('debitDate', isLessThanOrEqualTo: end)
        .orderBy('debitDate', descending: true)
        .limit(limit);
    if (startAfter != null) {
      oneOffQuery = oneOffQuery.startAfterDocument(startAfter);
    }

    final oneOffFuture = oneOffQuery.get();
    final recurringFuture = includeRecurring
        ? _collection
              .where('accountId', isEqualTo: accountId)
              .where('categoryId', isEqualTo: categoryId)
              .where('recurrence', isNotEqualTo: 'none')
              .orderBy('recurrence')
              .orderBy('debitDate', descending: true)
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
              final endDate = expense.endOfEndDate;
              return !expense.debitDate.isAfter(period.endOfMonth) &&
                  (endDate == null || !endDate.isBefore(period.startOfMonth));
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
    final end = Timestamp.fromDate(period.endOfMonth);

    Query<Map<String, dynamic>> oneOffQuery = _collection
        .where('accountId', isEqualTo: accountId)
        .where('recurrence', isEqualTo: 'none')
        .where('debitDate', isGreaterThanOrEqualTo: start)
        .where('debitDate', isLessThanOrEqualTo: end)
        .orderBy('debitDate', descending: true);
    if (categoryId != null) {
      oneOffQuery = oneOffQuery.where('categoryId', isEqualTo: categoryId);
    }

    Query<Map<String, dynamic>> recurringQuery = _collection
        .where('accountId', isEqualTo: accountId)
        .where('recurrence', isNotEqualTo: 'none')
        .orderBy('recurrence')
        .orderBy('debitDate', descending: true);
    if (categoryId != null) {
      recurringQuery = recurringQuery.where(
        'categoryId',
        isEqualTo: categoryId,
      );
    }

    final snapshots = await Future.wait([
      oneOffQuery
          .get(GetOptions(source: source))
          .timeout(const Duration(seconds: 8)),
      recurringQuery
          .get(GetOptions(source: source))
          .timeout(const Duration(seconds: 8)),
    ]);

    final expenses = [
      ...snapshots[0].docs.map((doc) => Expense.fromMap(doc.id, doc.data())),
      ...snapshots[1].docs.map((doc) => Expense.fromMap(doc.id, doc.data())),
    ];

    return expenses.where((expense) {
      if (!expense.isRecurring) return true;
      final endDate = expense.endOfEndDate;
      return !expense.debitDate.isAfter(period.endOfMonth) &&
          (endDate == null || !endDate.isBefore(period.startOfMonth));
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
        .timeout(const Duration(seconds: 8));
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
      final nextRef = _collection.doc();
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

  Future<void> deleteByAccountId(String accountId) async {
    try {
      final snapshot = await _collection
          .where('accountId', isEqualTo: accountId)
          .get(GetOptions(source: Source.cache));
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      AppLogger.debug('Cached expense deletion unavailable: $e');
    }
  }

  Future<void> deleteByCategoryId(String categoryId) async {
    try {
      final snapshot = await _collection
          .where('categoryId', isEqualTo: categoryId)
          .get(GetOptions(source: Source.cache));
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      AppLogger.debug('Cached category expense deletion unavailable: $e');
    }
  }
}
