import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ExpenseFirestore {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('users')
      .doc(_currentUserId)
      .collection('expenses');

  Future<List<Expense>> listByAccountId(String accountId) async {
    final snapshot = await _collection
        .where('accountId', isEqualTo: accountId)
        .orderBy('debitDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Expense.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<Expense?> create(Expense expense) async {
    final docRef = await _collection.add(expense.toCreateMap());
    final snapshot = await docRef.get();
    final data = snapshot.data();
    if (data == null) return null;
    return Expense.fromMap(docRef.id, data);
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
      final snapshot = await _collection.where('accountId', isEqualTo: accountId).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      AppLogger.error('Failed to delete expenses for account $accountId', e);
    }
  }

  Future<void> deleteByCategoryId(String categoryId) async {
    try {
      final snapshot = await _collection.where('categoryId', isEqualTo: categoryId).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      AppLogger.error('Failed to delete expenses for category $categoryId', e);
    }
  }
}