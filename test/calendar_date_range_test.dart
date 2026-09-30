import 'package:budgly/src/models/budget/calendar_date_range.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarDateRange', () {
    test('uses an inclusive start and exclusive end', () {
      final range = CalendarDateRange(
        start: DateTime(2026, 3, 1),
        endExclusive: DateTime(2026, 4, 1),
      );

      expect(range.contains(DateTime(2026, 3, 1)), isTrue);
      expect(range.contains(DateTime(2026, 3, 31)), isTrue);
      expect(range.contains(DateTime(2026, 4, 1)), isFalse);
    });

    test('normalizes time-of-day before comparing business dates', () {
      final range = CalendarDateRange(
        start: DateTime(2026, 3, 1, 18),
        endExclusive: DateTime(2026, 4, 1, 2),
      );

      expect(range.contains(DateTime(2026, 3, 31, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 4, 1, 0, 1)), isFalse);
    });

    test('rejects an empty or reversed range', () {
      expect(
        () => CalendarDateRange(
          start: DateTime(2026, 3, 1),
          endExclusive: DateTime(2026, 3, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => CalendarDateRange(
          start: DateTime(2026, 4, 1),
          endExclusive: DateTime(2026, 3, 1),
        ),
        throwsArgumentError,
      );
    });

    test('overlap uses the same half-open contract', () {
      final march = const Period(year: 2026, month: 3).range;
      final april = const Period(year: 2026, month: 4).range;
      final overlapping = CalendarDateRange(
        start: DateTime(2026, 3, 31),
        endExclusive: DateTime(2026, 4, 2),
      );

      expect(march.overlaps(april), isFalse);
      expect(march.overlaps(overlapping), isTrue);
    });
  });
}
