import 'dart:math' as math;

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

  bool get isRecurring => this != RecurrenceType.none;

  int? get _months => switch (this) {
    RecurrenceType.monthly => 1,
    RecurrenceType.bimonthly => 2,
    RecurrenceType.trimonthly => 3,
    RecurrenceType.halfyearly => 6,
    RecurrenceType.yearly => 12,
    RecurrenceType.biyearly => 24,
    _ => null,
  };

  int? get _days => switch (this) {
    RecurrenceType.daily => 1,
    RecurrenceType.weekly => 7,
    _ => null,
  };

  DateTime nextOccurrenceAfter(DateTime date, {int? anchorDay}) {
    final days = _days;
    if (days != null) return DateTime(date.year, date.month, date.day + days);
    final months = _months;
    if (months == null) return date;
    return addMonthsClamped(date, months, anchorDay: anchorDay ?? date.day);
  }

  DateTime previousOccurrenceBefore(DateTime date, {int? anchorDay}) {
    final days = _days;
    if (days != null) return DateTime(date.year, date.month, date.day - days);
    final months = _months;
    if (months == null) return date;
    return addMonthsClamped(date, -months, anchorDay: anchorDay ?? date.day);
  }

  DateTime firstOccurrenceOnOrAfter(
    DateTime anchor,
    DateTime target, {
    int? anchorDay,
  }) {
    var date = anchor;
    if (date.isBefore(target)) {
      final days = _days;
      final months = _months;
      if (days != null) {

        final dateUtc = DateTime.utc(date.year, date.month, date.day);
        final targetUtc = DateTime.utc(target.year, target.month, target.day);
        final steps = targetUtc.difference(dateUtc).inDays ~/ days;
        if (steps > 0) {
          date = DateTime(date.year, date.month, date.day + steps * days);
        }
      } else if (months != null) {
        final delta =
            (target.year - date.year) * 12 + (target.month - date.month);
        final steps = delta ~/ months;
        if (steps > 0) {
          date = addMonthsClamped(
            date,
            steps * months,
            anchorDay: anchorDay ?? anchor.day,
          );
        }
      }
      while (date.isBefore(target)) {
        final next = nextOccurrenceAfter(
          date,
          anchorDay: anchorDay ?? anchor.day,
        );
        if (!next.isAfter(date)) break;
        date = next;
      }
    }
    return date;
  }

  static RecurrenceType fromString(String? value) {
    return RecurrenceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RecurrenceType.none,
    );
  }
}

DateTime addMonthsClamped(DateTime date, int months, {int? anchorDay}) {
  final day = anchorDay ?? date.day;
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(day, lastDay));
}
