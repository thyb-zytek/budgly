import 'dart:math' as math;

/// How often a recurring expense repeats.
///
/// `none` is a one-off expense. The other values describe the interval
/// between two occurrences. Month-based recurrences clamp the day of the
/// month (Jan 31 → Feb 28) so the anchor never rolls into the next month.
/// Clamping is "sticky": when a caller walks occurrences with the same
/// anchor day, the day is restored once the target month is long enough
/// (Jan 31 → Feb 28 → Mar 31).
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

  /// Next occurrence strictly after [date].
  ///
  /// For month-based recurrences, [anchorDay] is the day-of-month of the
  /// original anchor (the expense's debit date) so clamping stays sticky.
  /// When omitted it defaults to the day of [date].
  DateTime nextOccurrenceAfter(DateTime date, {int? anchorDay}) {
    final days = _days;
    if (days != null) return DateTime(date.year, date.month, date.day + days);
    final months = _months;
    if (months == null) return date;
    return addMonthsClamped(date, months, anchorDay: anchorDay ?? date.day);
  }

  /// Previous occurrence strictly before [date].
  ///
  /// Same sticky-clamping semantics as [nextOccurrenceAfter].
  DateTime previousOccurrenceBefore(DateTime date, {int? anchorDay}) {
    final days = _days;
    if (days != null) return DateTime(date.year, date.month, date.day - days);
    final months = _months;
    if (months == null) return date;
    return addMonthsClamped(date, -months, anchorDay: anchorDay ?? date.day);
  }

  /// First occurrence on or after [anchor] that is also on or after [target].
  ///
  /// Jumps straight to [target]'s window (instead of walking every single
  /// occurrence since [anchor]) before fine-stepping to the exact date.
  DateTime firstOccurrenceOnOrAfter(DateTime anchor, DateTime target) {
    var date = anchor;
    if (date.isBefore(target)) {
      final days = _days;
      final months = _months;
      if (days != null) {
        // Use calendar dates in UTC so daylight-saving transitions do not
        // turn a 24-hour calendar interval into 23/25 elapsed hours.
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
          date = addMonthsClamped(date, steps * months, anchorDay: anchor.day);
        }
      }
      while (date.isBefore(target)) {
        final next = nextOccurrenceAfter(date, anchorDay: anchor.day);
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

/// Adds [months] months to [date], clamping the day to the target month's
/// length (Jan 31 + 1 month → Feb 28) so the result never overflows.
///
/// When [anchorDay] is given, the day-of-month kept is that anchor day
/// instead of [date]'s own day (sticky clamping).
DateTime addMonthsClamped(DateTime date, int months, {int? anchorDay}) {
  final day = anchorDay ?? date.day;
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(day, lastDay));
}
