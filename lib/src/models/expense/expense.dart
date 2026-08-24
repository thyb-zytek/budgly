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

  final List<String> debitedOccurrences;

  /// One-off amount corrections for individual occurrences.
  final Map<String, double> amountOverrides;

  /// Amount changes effective from a given occurrence date onward.
  ///
  /// The map is keyed by ISO date and stores the amount that becomes the
  /// recurring template value from that date onward.
  final Map<String, double> amountHistory;
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
    this.amountOverrides = const {},
    this.amountHistory = const {},
    this.createdAt,
    this.updatedAt,
    this.account,
    this.category,
  });

  bool get isRecurring => recurrence.isRecurring;

  /// Returns the amount that applies to this occurrence.
  ///
  /// The recurring expense keeps its current amount as the template value.
  /// Historical or explicitly corrected occurrences can override that value
  /// through [amountOverrides].
  double amountAt(DateTime date) {
    final override = amountOverrides[isoDate(date)];
    if (override != null) return override;

    var effectiveAmount = amount;
    DateTime? latestChangeDate;

    for (final entry in amountHistory.entries) {
      final changeDate = DateTime.tryParse(entry.key);
      if (changeDate == null || changeDate.isAfter(date)) continue;
      if (latestChangeDate == null || changeDate.isAfter(latestChangeDate)) {
        latestChangeDate = changeDate;
        effectiveAmount = entry.value;
      }
    }

    return effectiveAmount;
  }

  /// Applies a recurring amount change while keeping previous occurrence
  /// amounts stable.
  Expense withRecurringAmountChange(DateTime occurrenceDate, double newAmount) {
    if (!isRecurring) return copyWith(amount: newAmount);

    final key = isoDate(occurrenceDate);
    final currentAmount = amountAt(occurrenceDate);
    if (currentAmount == newAmount) return this;

    final overrides = Map<String, double>.from(amountOverrides);

    // An existing override is a one-off value for this occurrence.
    if (overrides.containsKey(key)) {
      overrides[key] = newAmount;
      return copyWith(amountOverrides: overrides);
    }

    final dateOnly = DateTime(
      occurrenceDate.year,
      occurrenceDate.month,
      occurrenceDate.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isHistorical =
        dateOnly.isBefore(today) || isDebitedAt(occurrenceDate);

    if (isHistorical) {
      overrides[key] = newAmount;
      return copyWith(amountOverrides: overrides);
    }

    // A current/future edit changes the recurring template from this
    // occurrence onward. Keep the existing amount changes as effective-date
    // entries instead of copying every historical occurrence into the
    // document.
    final history = Map<String, double>.from(amountHistory);
    final debitDay = DateTime(
      debitDate.year,
      debitDate.month,
      debitDate.day,
    );
    if (history.isEmpty && dateOnly.isAfter(debitDay)) {
      history[isoDate(debitDate)] = amount;
    }
    history[key] = newAmount;

    return copyWith(
      amount: newAmount,
      amountHistory: history,
    );
  }

  bool isDebitedAt(DateTime date) {
    if (!isRecurring) return isDebited;
    return debitedOccurrences.contains(isoDate(date));
  }

  static String isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    final rawDebited = map['debitedOccurrences'];
    final rawAmountOverrides = map['amountOverrides'];
    final rawAmountHistory = map['amountHistory'];
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
      amountOverrides: rawAmountOverrides is Map
          ? rawAmountOverrides.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num).toDouble(),
              ),
            )
          : const {},
      amountHistory: rawAmountHistory is Map
          ? rawAmountHistory.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num).toDouble(),
              ),
            )
          : const {},
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
      'amountOverrides': amountOverrides,
      'amountHistory': amountHistory,
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
      'amountOverrides': amountOverrides,
      'amountHistory': amountHistory,
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
    Map<String, double>? amountOverrides,
    Map<String, double>? amountHistory,
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
      amountOverrides: amountOverrides ?? this.amountOverrides,
      amountHistory: amountHistory ?? this.amountHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      account: account ?? this.account,
      category: category ?? this.category,
    );
  }
}
