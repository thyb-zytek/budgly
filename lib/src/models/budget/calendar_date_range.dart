/// A half-open range of business calendar dates: [start, endExclusive).
///
/// Business dates in Budgly have no time-of-day semantics. Using an exclusive
/// upper bound avoids the fragile "last millisecond of the day" convention
/// and makes Firestore and in-memory filtering use the same contract.
class CalendarDateRange {
  final DateTime start;
  final DateTime endExclusive;

  CalendarDateRange({required DateTime start, required DateTime endExclusive})
    : start = _calendarDate(start),
      endExclusive = _calendarDate(endExclusive) {
    if (!this.start.isBefore(this.endExclusive)) {
      throw ArgumentError.value(
        endExclusive,
        'endExclusive',
        'must be after start',
      );
    }
  }

  bool contains(DateTime value) {
    final day = _calendarDate(value);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  bool overlaps(CalendarDateRange other) =>
      start.isBefore(other.endExclusive) && other.start.isBefore(endExclusive);

  static DateTime _calendarDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
