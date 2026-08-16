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

  Future<AccountBudget> setRevenue(String accountId, int year, int month, double revenue) async {
    final id = _docId(accountId, year, month);
    final budget = AccountBudget(accountId: accountId, year: year, month: month, revenue: revenue);
    await _collection.doc(id).set(budget.toMap(), SetOptions(merge: true));
    return budget.copyWith(id: id);
  }
}