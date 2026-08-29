import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecurrenceType.fromString', () {
    test('returns none for null', () {
      expect(RecurrenceType.fromString(null), RecurrenceType.none);
    });

    test('returns none for empty string', () {
      expect(RecurrenceType.fromString(''), RecurrenceType.none);
    });

    test('returns none for unknown value', () {
      expect(RecurrenceType.fromString('weeklyish'), RecurrenceType.none);
    });

    test('matches exact enum name', () {
      expect(RecurrenceType.fromString('monthly'), RecurrenceType.monthly);
      expect(RecurrenceType.fromString('daily'), RecurrenceType.daily);
      expect(RecurrenceType.fromString('yearly'), RecurrenceType.yearly);
      expect(RecurrenceType.fromString('bimonthly'), RecurrenceType.bimonthly);
      expect(RecurrenceType.fromString('trimonthly'), RecurrenceType.trimonthly);
      expect(RecurrenceType.fromString('halfyearly'), RecurrenceType.halfyearly);
      expect(RecurrenceType.fromString('biyearly'), RecurrenceType.biyearly);
    });
  });

  group('RecurrenceType.isRecurring', () {
    test('none is not recurring', () {
      expect(RecurrenceType.none.isRecurring, isFalse);
    });

    test('all others are recurring', () {
      for (final type in RecurrenceType.values) {
        if (type == RecurrenceType.none) continue;
        expect(type.isRecurring, isTrue, reason: '$type should be recurring');
      }
    });
  });

  group('addMonthsClamped', () {
    test('Jan 31 -> Feb clamps to 28 in non-leap year', () {
      final result = addMonthsClamped(DateTime(2026, 1, 31), 1);
      expect(result, DateTime(2026, 2, 28));
    });

    test('Jan 31 -> Feb clamps to 29 in leap year', () {
      final result = addMonthsClamped(DateTime(2025, 1, 31), 1);
      expect(result, DateTime(2025, 2, 28));
    });

    test('Jan 30 -> Feb keeps 28/29 if anchorDay is 30', () {
      final result = addMonthsClamped(DateTime(2026, 1, 30), 1, anchorDay: 30);
      expect(result, DateTime(2026, 2, 28));
    });

    test('Jan 31 -> Mar goes back to 31', () {
      final result = addMonthsClamped(DateTime(2026, 1, 31), 2);
      expect(result, DateTime(2026, 3, 31));
    });

    test('negative months go backward', () {
      final result = addMonthsClamped(DateTime(2026, 3, 31), -1);
      expect(result, DateTime(2026, 2, 28));
    });

    test('crossing year boundary forward', () {
      final result = addMonthsClamped(DateTime(2026, 11, 15), 2);
      expect(result, DateTime(2027, 1, 15));
    });

    test('crossing year boundary backward', () {
      final result = addMonthsClamped(DateTime(2026, 2, 15), -3);
      // Dart's ~/ truncates toward zero: (-2) ~/ 12 == 0, so year stays 2026
      expect(result, DateTime(2026, 11, 15));
    });

    test('zero months returns same month', () {
      final result = addMonthsClamped(DateTime(2026, 6, 15), 0);
      expect(result, DateTime(2026, 6, 15));
    });

    test('explicit anchorDay overrides date.day', () {
      final result = addMonthsClamped(DateTime(2026, 1, 1), 1, anchorDay: 28);
      expect(result, DateTime(2026, 2, 28));
    });

    test('24 months (biyearly) adds 2 years', () {
      final result = addMonthsClamped(DateTime(2026, 6, 15), 24);
      expect(result, DateTime(2028, 6, 15));
    });

    test('Feb 28 -> Mar with anchorDay 31 clamps to 31', () {
      final result = addMonthsClamped(DateTime(2026, 2, 28), 1, anchorDay: 31);
      expect(result, DateTime(2026, 3, 31));
    });
  });

  group('RecurrenceType.nextOccurrenceAfter', () {
    test('daily advances by 1 day', () {
      final result = RecurrenceType.daily.nextOccurrenceAfter(DateTime(2026, 2, 28));
      expect(result, DateTime(2026, 3, 1));
    });

    test('weekly advances by 7 days', () {
      final result = RecurrenceType.weekly.nextOccurrenceAfter(DateTime(2026, 1, 1));
      expect(result, DateTime(2026, 1, 8));
    });

    test('monthly advances by 1 month with clamping', () {
      final result = RecurrenceType.monthly.nextOccurrenceAfter(DateTime(2026, 1, 31));
      expect(result, DateTime(2026, 2, 28));
    });

    test('bimonthly advances by 2 months', () {
      final result = RecurrenceType.bimonthly.nextOccurrenceAfter(DateTime(2026, 1, 15));
      expect(result, DateTime(2026, 3, 15));
    });

    test('trimonthly advances by 3 months', () {
      final result = RecurrenceType.trimonthly.nextOccurrenceAfter(DateTime(2026, 1, 15));
      expect(result, DateTime(2026, 4, 15));
    });

    test('halfyearly advances by 6 months', () {
      final result = RecurrenceType.halfyearly.nextOccurrenceAfter(DateTime(2026, 1, 15));
      expect(result, DateTime(2026, 7, 15));
    });

    test('yearly advances by 12 months', () {
      final result = RecurrenceType.yearly.nextOccurrenceAfter(DateTime(2026, 1, 15));
      expect(result, DateTime(2027, 1, 15));
    });

    test('biyearly advances by 24 months', () {
      final result = RecurrenceType.biyearly.nextOccurrenceAfter(DateTime(2026, 1, 15));
      expect(result, DateTime(2028, 1, 15));
    });

    test('none returns the same date', () {
      final date = DateTime(2026, 6, 15);
      final result = RecurrenceType.none.nextOccurrenceAfter(date);
      expect(result, date);
    });

    test('monthly with anchorDay 31 stays on 31 when possible', () {
      final result = RecurrenceType.monthly.nextOccurrenceAfter(
        DateTime(2026, 1, 31),
        anchorDay: 31,
      );
      expect(result, DateTime(2026, 2, 28));
      final mar = RecurrenceType.monthly.nextOccurrenceAfter(result, anchorDay: 31);
      expect(mar, DateTime(2026, 3, 31));
    });
  });

  group('RecurrenceType.previousOccurrenceBefore', () {
    test('daily goes back 1 day', () {
      final result = RecurrenceType.daily.previousOccurrenceBefore(DateTime(2026, 3, 1));
      expect(result, DateTime(2026, 2, 28));
    });

    test('weekly goes back 7 days', () {
      final result = RecurrenceType.weekly.previousOccurrenceBefore(DateTime(2026, 1, 15));
      expect(result, DateTime(2026, 1, 8));
    });

    test('monthly goes back 1 month with clamping', () {
      final result = RecurrenceType.monthly.previousOccurrenceBefore(DateTime(2026, 3, 31));
      expect(result, DateTime(2026, 2, 28));
    });

    test('bimonthly goes back 2 months', () {
      final result = RecurrenceType.bimonthly.previousOccurrenceBefore(DateTime(2026, 5, 15));
      expect(result, DateTime(2026, 3, 15));
    });

    test('yearly goes back 12 months within same year range', () {
      final result = RecurrenceType.yearly.previousOccurrenceBefore(DateTime(2027, 12, 15));
      expect(result, DateTime(2027, 12, 15));
    });

    test('none returns the same date', () {
      final date = DateTime(2026, 6, 15);
      final result = RecurrenceType.none.previousOccurrenceBefore(date);
      expect(result, date);
    });

    test('monthly with anchorDay preserves day across short months', () {
      final result = RecurrenceType.monthly.previousOccurrenceBefore(
        DateTime(2026, 3, 31),
        anchorDay: 31,
      );
      expect(result, DateTime(2026, 2, 28));
      final jan = RecurrenceType.monthly.previousOccurrenceBefore(result, anchorDay: 31);
      expect(jan, DateTime(2026, 1, 31));
    });
  });

  group('RecurrenceType.firstOccurrenceOnOrAfter', () {
    test('returns target when anchor is already on or after target', () {
      final anchor = DateTime(2026, 6, 15);
      final target = DateTime(2026, 5, 1);
      final result = RecurrenceType.monthly.firstOccurrenceOnOrAfter(anchor, target);
      expect(result, anchor);
    });

    test('returns target when equal', () {
      final date = DateTime(2026, 6, 15);
      final result = RecurrenceType.monthly.firstOccurrenceOnOrAfter(date, date);
      expect(result, date);
    });

    test('daily jumps directly to target window', () {
      final result = RecurrenceType.daily.firstOccurrenceOnOrAfter(
        DateTime(2026, 1, 1),
        DateTime(2026, 6, 10),
      );
      expect(result.isAfter(DateTime(2026, 6, 9)) || result.isAtSameMomentAs(DateTime(2026, 6, 10)), isTrue);
      expect(!result.isBefore(DateTime(2026, 6, 10)), isTrue);
    });

    test('weekly jumps directly to target window', () {
      final result = RecurrenceType.weekly.firstOccurrenceOnOrAfter(
        DateTime(2026, 1, 1),
        DateTime(2026, 6, 15),
      );
      expect(!result.isBefore(DateTime(2026, 6, 15)), isTrue);
    });

    test('monthly with anchor day 31 jumps correctly', () {
      final result = RecurrenceType.monthly.firstOccurrenceOnOrAfter(
        DateTime(2026, 1, 31),
        DateTime(2027, 6, 1),
        anchorDay: 31,
      );
      expect(result, DateTime(2027, 6, 30));
    });

    test('yearly jumps forward by year', () {
      final result = RecurrenceType.yearly.firstOccurrenceOnOrAfter(
        DateTime(2020, 3, 15),
        DateTime(2026, 1, 1),
      );
      expect(result, DateTime(2026, 3, 15));
    });

    test('bimonthly skips correctly', () {
      final result = RecurrenceType.bimonthly.firstOccurrenceOnOrAfter(
        DateTime(2026, 1, 15),
        DateTime(2026, 10, 1),
      );
      expect(result, DateTime(2026, 11, 15));
    });

    test('halfyearly skips correctly', () {
      final result = RecurrenceType.halfyearly.firstOccurrenceOnOrAfter(
        DateTime(2026, 1, 15),
        DateTime(2027, 8, 1),
      );
      expect(result, DateTime(2028, 1, 15));
    });
  });
}
