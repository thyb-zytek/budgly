import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/stored_calendar_date.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed UTC instants only: the results must not depend on the timezone of the
/// machine running the suite (CI runs in UTC, developers do not).
Timestamp utc(int y, int m, int d, [int h = 0, int min = 0]) =>
    Timestamp.fromDate(DateTime.utc(y, m, d, h, min));

void main() {
  group('calendarDateToTimestamp', () {
    test(
      'stores midnight UTC of the calendar day, whatever the time of day',
      () {
        final stored = calendarDateToTimestamp(DateTime(2026, 3, 1, 23, 59));

        expect(stored.toDate().toUtc(), DateTime.utc(2026, 3, 1));
      },
    );

    test('round-trips through calendarDateFromTimestamp', () {
      for (final day in [
        DateTime(2026, 3, 29), // Europe/Paris spring-forward day
        DateTime(2026, 10, 25), // Europe/Paris fall-back day
        DateTime(2028, 2, 29), // leap day
        DateTime(2026, 12, 31),
        DateTime(2026, 1, 1),
      ]) {
        expect(calendarDateFromTimestamp(calendarDateToTimestamp(day)), day);
      }
    });
  });

  group('calendarDateFromTimestamp', () {
    test('current format: midnight UTC is that calendar day', () {
      expect(calendarDateFromTimestamp(utc(2026, 3, 1)), DateTime(2026, 3, 1));
    });

    test('legacy value written in Paris (UTC+1): local midnight = 23:00 UTC the day before', () {
      expect(
        calendarDateFromTimestamp(utc(2026, 2, 28, 23)),
        DateTime(2026, 3, 1),
      );
    });

    test('legacy value written in Paris during summer time (UTC+2)', () {
      expect(
        calendarDateFromTimestamp(utc(2026, 6, 14, 22)),
        DateTime(2026, 6, 15),
      );
    });

    test('legacy value written in New York (UTC-5 / UTC-4): same UTC day', () {
      expect(
        calendarDateFromTimestamp(utc(2026, 3, 1, 5)),
        DateTime(2026, 3, 1),
      );
      expect(
        calendarDateFromTimestamp(utc(2026, 7, 1, 4)),
        DateTime(2026, 7, 1),
      );
    });

    test('legacy value written in Tokyo (UTC+9)', () {
      expect(
        calendarDateFromTimestamp(utc(2026, 2, 28, 15)),
        DateTime(2026, 3, 1),
      );
    });

    test('a month or year boundary is crossed correctly', () {
      expect(
        calendarDateFromTimestamp(utc(2026, 12, 31, 23)),
        DateTime(2027, 1, 1),
      );
    });
  });

  group('range query bounds', () {
    test(
      'the start bound reaches back far enough for any eastern legacy writer',
      () {
        final start = calendarDateQueryStart(DateTime(2026, 3, 1)).toDate();

        // Paris legacy value for 1 March = 28 Feb 23:00 UTC must be inside.
        expect(!utc(2026, 2, 28, 23).toDate().isBefore(start), isTrue);
      },
    );

    test('the end bound is the UTC midnight of the exclusive day', () {
      expect(
        calendarDateQueryEndExclusive(DateTime(2026, 4, 1)).toDate().toUtc(),
        DateTime.utc(2026, 4, 1),
      );
    });
  });

  group('Expense persistence', () {
    test('toCreateMap writes UTC midnight for debitDate and endDate', () {
      final expense = Expense(
        accountId: 'a',
        categoryId: 'c',
        name: 'n',
        amount: 1,
        debitDate: DateTime(2026, 3, 29, 14, 30),
        endDate: DateTime(2026, 10, 25),
      );

      final map = expense.toCreateMap();

      expect(
        (map['debitDate'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 3, 29),
      );
      expect(
        (map['endDate'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 10, 25),
      );
    });

    test(
      'fromMap reads both the new and the legacy format to the same day',
      () {
        Map<String, dynamic> map(Timestamp debit) => {
          'accountId': 'a',
          'categoryId': 'c',
          'debitDate': debit,
        };

        expect(
          Expense.fromMap('x', map(utc(2026, 3, 1))).debitDate,
          DateTime(2026, 3, 1),
        );
        expect(
          Expense.fromMap('x', map(utc(2026, 2, 28, 23))).debitDate,
          DateTime(2026, 3, 1),
        );
      },
    );
  });
}
