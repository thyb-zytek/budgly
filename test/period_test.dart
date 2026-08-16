import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('en_US');
  });

  group('Period', () {
    test('addMonths crosses year boundaries', () {
      final period = const Period(year: 2026, month: 11);
      expect(period.addMonths(1), const Period(year: 2026, month: 12));
      expect(period.addMonths(2), const Period(year: 2027, month: 1));
      expect(period.addMonths(-12), const Period(year: 2025, month: 11));
    });

    test('previous and next navigate one month', () {
      final january = const Period(year: 2026, month: 1);
      expect(january.previous, const Period(year: 2025, month: 12));
      expect(january.next, const Period(year: 2026, month: 2));
    });

    test('contains bounds the period to its month', () {
      final period = const Period(year: 2026, month: 3);
      expect(period.contains(DateTime(2026, 3, 1)), isTrue);
      expect(period.contains(DateTime(2026, 3, 31)), isTrue);
      expect(period.contains(DateTime(2026, 2, 28)), isFalse);
      expect(period.contains(DateTime(2026, 4, 1)), isFalse);
    });

    test('endOfMonth is the last millisecond of the month', () {
      final period = const Period(year: 2026, month: 2);
      expect(period.endOfMonth, DateTime(2026, 3, 1).subtract(const Duration(milliseconds: 1)));
    });

    test('isBefore and isAfter compare by year and month', () {
      final a = const Period(year: 2025, month: 12);
      final b = const Period(year: 2026, month: 1);
      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect(a.isAfter(b), isFalse);
    });

    test('equals and hashCode reflect year and month', () {
      const a = Period(year: 2026, month: 5);
      const b = Period(year: 2026, month: 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('label capitalizes the month name', () {
      final period = const Period(year: 2026, month: 3);
      expect(period.label('fr_FR'), 'Mars 2026');
      expect(period.label('en_US'), 'March 2026');
    });
  });
}
