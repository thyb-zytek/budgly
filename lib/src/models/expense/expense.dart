import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/models/expense/expense_occurrence_exception.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String? id;
  final String accountId;
  final String categoryId;
  final String name;
  final double amount;
  final DateTime debitDate;
  final DateTime? endDate;
  final RecurrenceType recurrence;
  final int recurrenceAnchorDay;
  final bool isDebited;

  final List<String> debitedOccurrences;
  final List<ExpenseOccurrenceException> occurrenceExceptions;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Account? account;
  final Category? category;

  Expense({
    this.id,
    required this.accountId,
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.debitDate,
    this.endDate,
    this.recurrence = RecurrenceType.none,
    int? recurrenceAnchorDay,
    this.isDebited = false,
    this.debitedOccurrences = const [],
    this.occurrenceExceptions = const [],
    this.createdAt,
    this.updatedAt,
    this.account,
    this.category,
  }) : recurrenceAnchorDay = recurrenceAnchorDay ?? debitDate.day;

  bool get isRecurring => recurrence.isRecurring;

  DateTime? get endOfEndDate {
    final end = endDate;
    if (end == null) return null;
    return DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
  }

  ExpenseOccurrenceException? exceptionAt(DateTime date) {
    final key = '${id ?? ''}@${isoDate(date)}';
    for (final exception in occurrenceExceptions) {
      if (exception.key == key) return exception;
    }
    return null;
  }

  bool isDebitedAt(DateTime date) {
    if (!isRecurring) return isDebited;
    final exception = exceptionAt(date);
    return exception?.isDebited ?? debitedOccurrences.contains(isoDate(date));
  }

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
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      isDebited: map['isDebited'] as bool? ?? false,
      debitedOccurrences: rawDebited is List
          ? rawDebited.cast<String>()
          : const [],
      occurrenceExceptions: (map['occurrenceExceptions'] as List?)
              ?.map((item) => ExpenseOccurrenceException.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList() ??
          const [],
      recurrence: RecurrenceType.fromString(map['recurrence'] as String?),
      recurrenceAnchorDay: (map['recurrenceAnchorDay'] as num?)?.toInt(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> _sharedFieldsMap() {
    return {
      'accountId': accountId,
      'categoryId': categoryId,
      'name': name,
      'amount': amount,
      'debitDate': Timestamp.fromDate(debitDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isDebited': isDebited,
      'debitedOccurrences': debitedOccurrences,
      'occurrenceExceptions': occurrenceExceptions.map((e) => e.toJson()).toList(),
      'recurrence': recurrence.name,
      'recurrenceAnchorDay': recurrenceAnchorDay,
    };
  }

  /// JSON representation used by the persistent offline mutation queue.
  ///
  /// Firestore's [Timestamp] and [FieldValue] types cannot be serialized by
  /// [jsonEncode], so queued mutations use ISO-8601 strings instead.
  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'categoryId': categoryId,
        'name': name,
        'amount': amount,
        'debitDate': debitDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'recurrence': recurrence.name,
        'recurrenceAnchorDay': recurrenceAnchorDay,
        'isDebited': isDebited,
        'debitedOccurrences': debitedOccurrences,
        'occurrenceExceptions': occurrenceExceptions.map((e) => e.toJson()).toList(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id']?.toString(),
        accountId: json['accountId'] as String,
        categoryId: json['categoryId'] as String,
        name: json['name'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        debitDate: DateTime.parse(json['debitDate'].toString()),
        endDate: json['endDate'] == null
            ? null
            : DateTime.parse(json['endDate'].toString()),
        recurrence: RecurrenceType.fromString(json['recurrence'] as String?),
        recurrenceAnchorDay: (json['recurrenceAnchorDay'] as num?)?.toInt(),
        isDebited: json['isDebited'] as bool? ?? false,
        debitedOccurrences: (json['debitedOccurrences'] as List?)
                ?.map((value) => value.toString())
                .toList() ??
            const [],
        occurrenceExceptions: (json['occurrenceExceptions'] as List?)
                ?.map((item) => ExpenseOccurrenceException.fromJson(
                      Map<String, dynamic>.from(item as Map),
                    ))
                .toList() ??
            const [],
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'].toString()),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'].toString()),
      );

  Map<String, dynamic> toCreateMap() {
    return {
      ..._sharedFieldsMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      ..._sharedFieldsMap(),
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
    DateTime? endDate,
    bool clearEndDate = false,
    RecurrenceType? recurrence,
    int? recurrenceAnchorDay,
    bool? isDebited,
    List<String>? debitedOccurrences,
    List<ExpenseOccurrenceException>? occurrenceExceptions,
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
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      recurrence: recurrence ?? this.recurrence,
      recurrenceAnchorDay: recurrenceAnchorDay ?? this.recurrenceAnchorDay,
      isDebited: isDebited ?? this.isDebited,
      debitedOccurrences: debitedOccurrences ?? this.debitedOccurrences,
      occurrenceExceptions: occurrenceExceptions ?? this.occurrenceExceptions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      account: account ?? this.account,
      category: category ?? this.category,
    );
  }
}
