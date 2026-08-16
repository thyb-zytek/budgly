enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
  bimonthly,
  trimonthly,
  halfyearly,
  biyearly;

  static RecurrenceType fromString(String? value) {
    return RecurrenceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RecurrenceType.none,
    );
  }
}