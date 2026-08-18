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

  /// ISO dates (yyyy-MM-dd) of the occurrences already marked debited.
  /// Only relevant for recurring expenses: each occurrence keeps its own
  /// debited state so a subscription can be "paid" one month and not the
  /// next. One-off expenses use the [isDebited] flag instead.
  final List<String> debitedOccurrences;
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
    this.debitedOccurrences = const [],
    this.createdAt,
    this.updatedAt,
    this.account,
    this.category,
  });

  bool get isRecurring => recurrence.isRecurring;

  /// Whether the occurrence on [date] is marked debited.
  bool isDebitedAt(DateTime date) {
    if (!isRecurring) return isDebited;
    return debitedOccurrences.contains(isoDate(date));
  }

  /// Stable day-based key, e.g. "2026-03-15". Used to track the per
  /// occurrence debited state of recurring expenses.
  static String isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    final rawDebited = map['debitedOccurrences'];
    return Expense(
      id: id,
      accountId: map['accountId'] as String,
      categoryId: map['categoryId'] as String,
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      debitDate: (map['debitDate'] as Timestamp).toDate(),
      isDebited: map['isDebited'] as bool,
      debitedOccurrences: rawDebited is List
          ? rawDebited.cast<String>()
          : const [],
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
      'debitedOccurrences': debitedOccurrences,
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
      'debitedOccurrences': debitedOccurrences,
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
    List<String>? debitedOccurrences,
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
      debitedOccurrences: debitedOccurrences ?? this.debitedOccurrences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      account: account ?? this.account,
      category: category ?? this.category,
    );
  }
}
