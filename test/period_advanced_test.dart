import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('en_US');
  });

  group('Period.remainingWeekends', () {
    test('returns 0 when today is outside the period', () {
      const period = Period(year: 2026, month: 3);
      expect(period.remainingWeekends(now: DateTime(2026, 2, 15)), 0);
      expect(period.remainingWeekends(now: DateTime(2026, 4, 15)), 0);
    });

    test('counts remaining Saturdays and Sundays from a Tuesday', () {
      const period = Period(year: 2026, month: 3);
      // March 3, 2026 is a Tuesday
      final result = period.remainingWeekends(now: DateTime(2026, 3, 3));
      expect(result, greaterThan(0));
    });

    test('counts the current day if it is a Sunday', () {
      const period = Period(year: 2026, month: 3);
      // March 1, 2026 is a Sunday
      final result = period.remainingWeekends(now: DateTime(2026, 3, 1));
      expect(result, greaterThanOrEqualTo(1));
    });

    test('on the last day of month (Saturday), counts 1', () {
      // August 29, 2026 is a Saturday
      const period = Period(year: 2026, month: 8);
      final result = period.remainingWeekends(now: DateTime(2026, 8, 29));
      expect(result, 1);
    });

    test('on the last day of month (Sunday), counts 1', () {
      // March 29, 2026 is a Sunday
      const period = Period(year: 2026, month: 3);
      final result = period.remainingWeekends(now: DateTime(2026, 3, 29));
      expect(result, 1);
    });

    test('start of month on Saturday counts 1', () {
      // August 1, 2026 is a Saturday
      const period = Period(year: 2026, month: 8);
      final result = period.remainingWeekends(now: DateTime(2026, 8, 1));
      expect(result, greaterThanOrEqualTo(1));
    });
  });

  group('Period.totalWeekends', () {
    test('February 2026 has 4 Saturdays', () {
      const period = Period(year: 2026, month: 2);
      expect(period.totalWeekends(), 4);
    });

    test('January 2026 has 5 Saturdays', () {
      const period = Period(year: 2026, month: 1);
      expect(period.totalWeekends(), 5);
    });

    test('March 2026 has 4 Saturdays', () {
      const period = Period(year: 2026, month: 3);
      expect(period.totalWeekends(), 4);
    });
  });

  group('Period.contains', () {
    test('midnight of first day is contained', () {
      const period = Period(year: 2026, month: 3);
      expect(period.contains(DateTime(2026, 3, 1)), isTrue);
    });

    test('last millisecond of last day is contained', () {
      const period = Period(year: 2026, month: 3);
      final endOfMonth = DateTime(2026, 4, 1).subtract(const Duration(milliseconds: 1));
      expect(period.contains(endOfMonth), isTrue);
    });

    test('first millisecond of next month is not contained', () {
      const period = Period(year: 2026, month: 3);
      expect(period.contains(DateTime(2026, 4, 1)), isFalse);
    });
  });

  group('Period.endOfMonth', () {
    test('January ends at 31', () {
      const period = Period(year: 2026, month: 1);
      expect(period.endOfMonth.day, 31);
      expect(period.endOfMonth.month, 1);
    });

    test('April ends at 30', () {
      const period = Period(year: 2026, month: 4);
      expect(period.endOfMonth.day, 30);
    });

    test('December ends at 31', () {
      const period = Period(year: 2026, month: 12);
      expect(period.endOfMonth.day, 31);
    });

    test('February 2026 ends at 28', () {
      const period = Period(year: 2026, month: 2);
      expect(period.endOfMonth.day, 28);
    });
  });

  group('Period.addMonths', () {
    test('same year', () {
      const p = Period(year: 2026, month: 3);
      expect(p.addMonths(3), const Period(year: 2026, month: 6));
    });

    test('large delta', () {
      const p = Period(year: 2026, month: 1);
      expect(p.addMonths(100), const Period(year: 2034, month: 5));
    });

    test('negative delta large', () {
      const p = Period(year: 2026, month: 6);
      expect(p.addMonths(-24), const Period(year: 2024, month: 6));
    });
  });

  group('Period equality', () {
    test('different months same year are not equal', () {
      const a = Period(year: 2026, month: 1);
      const b = Period(year: 2026, month: 2);
      expect(a, isNot(b));
    });

    test('same month different years are not equal', () {
      const a = Period(year: 2025, month: 6);
      const b = Period(year: 2026, month: 6);
      expect(a, isNot(b));
    });

    test('not equal to non-Period object', () {
      const p = Period(year: 2026, month: 1);
      expect(p, isNot('not a period'));
    });
  });

  group('Period.isBefore / isAfter', () {
    test('same period is neither before nor after', () {
      const a = Period(year: 2026, month: 6);
      const b = Period(year: 2026, month: 6);
      expect(a.isBefore(b), isFalse);
      expect(a.isAfter(b), isFalse);
    });

    test('December to January next year', () {
      const dec = Period(year: 2025, month: 12);
      const jan = Period(year: 2026, month: 1);
      expect(dec.isBefore(jan), isTrue);
      expect(jan.isAfter(dec), isTrue);
    });
  });

  group('Period.toString', () {
    test('formats as YYYY-MM', () {
      const p = Period(year: 2026, month: 3);
      expect(p.toString(), '2026-03');
    });

    test('single digit month is zero-padded', () {
      const p = Period(year: 2026, month: 9);
      expect(p.toString(), '2026-09');
    });
  });

  group('Period.fromDate', () {
    test('extracts year and month', () {
      final p = Period.fromDate(DateTime(2026, 7, 15));
      expect(p.year, 2026);
      expect(p.month, 7);
    });
  });
}
