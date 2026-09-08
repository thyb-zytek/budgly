/// A persisted override for one occurrence of a recurring expense.
///
/// The recurrence itself remains unchanged; the exception only changes the
/// projection of the keyed occurrence. This keeps historical occurrences
/// stable while still allowing a single occurrence to be edited, deleted or
/// moved to another debit date.
class ExpenseOccurrenceException {
  final String key;
  final double? amount;
  final String? name;
  final String? categoryId;
  final DateTime? debitDate;
  final bool deleted;
  final bool? isDebited;

  const ExpenseOccurrenceException({
    required this.key,
    this.amount,
    this.name,
    this.categoryId,
    this.debitDate,
    this.deleted = false,
    this.isDebited,
  });

  ExpenseOccurrenceException copyWith({
    double? amount,
    String? name,
    String? categoryId,
    DateTime? debitDate,
    bool? deleted,
    bool? isDebited,
  }) {
    return ExpenseOccurrenceException(
      key: key,
      amount: amount ?? this.amount,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      debitDate: debitDate ?? this.debitDate,
      deleted: deleted ?? this.deleted,
      isDebited: isDebited ?? this.isDebited,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'amount': amount,
        'name': name,
        'categoryId': categoryId,
        'debitDate': debitDate?.toIso8601String(),
        'deleted': deleted,
        'isDebited': isDebited,
      };

  factory ExpenseOccurrenceException.fromJson(Map<String, dynamic> json) {
    return ExpenseOccurrenceException(
      key: json['key'].toString(),
      amount: (json['amount'] as num?)?.toDouble(),
      name: json['name'] as String?,
      categoryId: json['categoryId'] as String?,
      debitDate: json['debitDate'] == null
          ? null
          : DateTime.parse(json['debitDate'].toString()),
      deleted: json['deleted'] as bool? ?? false,
      isDebited: json['isDebited'] as bool?,
    );
  }
}
