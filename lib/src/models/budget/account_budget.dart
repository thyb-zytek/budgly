import 'package:cloud_firestore/cloud_firestore.dart';

class AccountBudget {
  final String? id;
  final String accountId;
  final int year;
  final int month;
  final double revenue;
  final DateTime? updatedAt;

  const AccountBudget({
    this.id,
    required this.accountId,
    required this.year,
    required this.month,
    required this.revenue,
    this.updatedAt,
  });

  factory AccountBudget.fromMap(String id, Map<String, dynamic> map) {
    return AccountBudget(
      id: id,
      accountId: map['accountId'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'year': year,
      'month': month,
      'revenue': revenue,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AccountBudget copyWith({String? id, double? revenue}) {
    return AccountBudget(
      id: id ?? this.id,
      accountId: accountId,
      year: year,
      month: month,
      revenue: revenue ?? this.revenue,
      updatedAt: updatedAt,
    );
  }
}