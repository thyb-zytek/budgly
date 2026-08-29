import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Returns the most recent budget carrying a revenue among [budgets], scanning
/// in descending period order but never falling onto a period at or after
/// [before].
///
/// A period only inherits revenue from strictly earlier months.
AccountBudget? firstRevenueBefore(
  List<AccountBudget> budgets,
  Period before,
) {
  final ordered = List<AccountBudget>.from(budgets)
    ..sort((a, b) {
      if (a.year != b.year) return b.year.compareTo(a.year);
      return b.month.compareTo(a.month);
    });
  for (final budget in ordered) {
    if (!budget.period.isBefore(before)) continue;
    if (budget.revenue > 0) return budget;
  }
  return null;
}

class AccountBudgetFirestore {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No authenticated user');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('account_budgets');

  String _docId(String accountId, int year, int month) => '${accountId}_${year}_$month';

  Future<AccountBudget?> get(
    String accountId,
    int year,
    int month, {
    Source source = Source.server,
  }) async {
    final doc = await _collection
        .doc(_docId(accountId, year, month))
        .get(GetOptions(source: source));
    final data = doc.data();
    if (data == null) return null;
    return AccountBudget.fromMap(doc.id, data);
  }

  /// Returns the most recent budget whose period is strictly earlier than
  /// [before] and which bears a revenue (see [firstRevenueBefore]).
  Future<AccountBudget?> getMostRecentWithRevenue(
    String accountId, {
    required Period before,
    Source source = Source.server,
  }) async {
    final snapshot = await _collection
        .where('accountId', isEqualTo: accountId)
        .orderBy('year', descending: true)
        .orderBy('month', descending: true)
        .limit(60)
        .get(GetOptions(source: source));

    final budgets = snapshot.docs
        .map((doc) => AccountBudget.fromMap(doc.id, doc.data()))
        .toList();
    return firstRevenueBefore(budgets, before);
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
          .get(GetOptions(source: Source.cache));
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      AppLogger.debug('Cached budget deletion unavailable: $e');
    }
  }
}
