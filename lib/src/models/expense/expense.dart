import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String? id;
  final String accountId;
  final String categoryId;
  final String name;
  final double amount;
  final DateTime debitDate;
  final RecurrenceType recurrence;
  final bool isDebited;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Account? account;
  final Category? category;

  const Expense({
    this.id,
    required this.accountId,
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.debitDate,
    this.recurrence = RecurrenceType.none,
    this.isDebited = false,
    this.createdAt,
    this.updatedAt,
    this.account,
    this.category,
  });

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      accountId: map['accountId'] as String,
      categoryId: map['categoryId'] as String,
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      debitDate: (map['debitDate'] as Timestamp).toDate(),
      isDebited: map['isDebited'] as bool,
      recurrence: RecurrenceType.fromString(map['recurrence'] as String?),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'accountId': accountId,
      'categoryId': categoryId,
      'name': name,
      'amount': amount,
      'debitDate': Timestamp.fromDate(debitDate),
      'isDebited': isDebited,
      'recurrence': recurrence.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'accountId': accountId,
      'categoryId': categoryId,
      'name': name,
      'amount': amount,
      'debitDate': Timestamp.fromDate(debitDate),
      'isDebited': isDebited,
      'recurrence': recurrence.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Expense copyWith({
    String? id,
    String? accountId,
    String? categoryId,
    String? name,
    double? amount,
    DateTime? debitDate,
    RecurrenceType? recurrence,
    bool? isDebited,
    DateTime? createdAt,
    DateTime? updatedAt,
    Account? account,
    Category? category,
  }) {
    return Expense(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      debitDate: debitDate ?? this.debitDate,
      recurrence: recurrence ?? this.recurrence,
      isDebited: isDebited ?? this.isDebited,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      account: account ?? this.account,
      category: category ?? this.category,
    );
  }
}
