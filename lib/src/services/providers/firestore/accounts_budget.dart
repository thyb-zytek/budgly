import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountBudgetFirestore {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No authenticated user');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('account_budgets');

  String _docId(String accountId, int year, int month) => '${accountId}_${year}_$month';

  Future<AccountBudget?> get(String accountId, int year, int month) async {
    final doc = await _collection.doc(_docId(accountId, year, month)).get();
    final data = doc.data();
    if (data == null) return null;
    return AccountBudget.fromMap(doc.id, data);
  }

  Future<AccountBudget?> getMostRecentWithRevenue(String accountId) async {
    final snapshot = await _collection
        .where('accountId', isEqualTo: accountId)
        .orderBy('year', descending: true)
        .orderBy('month', descending: true)
        .limit(24)
        .get();

    for (final doc in snapshot.docs) {
      final budget = AccountBudget.fromMap(doc.id, doc.data());
      if (budget.revenue > 0) return budget;
    }
    return null;
  }

  Future<AccountBudget> setRevenue(String accountId, int year, int month, double revenue) async {
    final id = _docId(accountId, year, month);
    final budget = AccountBudget(accountId: accountId, year: year, month: month, revenue: revenue);
    await _collection.doc(id).set(budget.toMap(), SetOptions(merge: true));
    return budget.copyWith(id: id);
  }

  Future<void> deleteByAccountId(String accountId) async {
    try {
      final snapshot = await _collection
          .where('accountId', isEqualTo: accountId)
          .get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }
}
