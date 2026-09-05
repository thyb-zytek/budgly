import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _exp({
  String id = 'e1',
  DateTime? debitDate,
  DateTime? endDate,
  RecurrenceType recurrence = RecurrenceType.none,
  int? anchorDay,
  String accountId = 'acc-1',
  String categoryId = 'cat-1',
  List<String> debited = const [],
}) => Expense(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      name: 'Test',
      amount: 10,
      debitDate: debitDate ?? DateTime(2026, 1, 15),
      endDate: endDate,
      recurrence: recurrence,
      recurrenceAnchorDay: anchorDay,
      debitedOccurrences: debited,
    );

void main() {
  group('Recurrence frequencies', () {
    test('all supported frequencies exist', () {
      expect(RecurrenceType.values, containsAll(<RecurrenceType>{
        RecurrenceType.none,
        RecurrenceType.daily,
        RecurrenceType.weekly,
        RecurrenceType.monthly,
        RecurrenceType.bimonthly,
        RecurrenceType.trimonthly,
        RecurrenceType.halfyearly,
        RecurrenceType.yearly,
        RecurrenceType.biyearly,
      }));
    });

    test('daily generates each day', () {
      final exp = _exp(debitDate: DateTime(2026, 3, 1), recurrence: RecurrenceType.daily);
      final occ = expandExpenseOccurrencesBetween(exp, DateTime(2026, 3, 1), DateTime(2026, 3, 3));
      expect(occ.map((o) => o.date), [DateTime(2026, 3, 1), DateTime(2026, 3, 2), DateTime(2026, 3, 3)]);
    });

    test('weekly generates every 7 days', () {
      final exp = _exp(debitDate: DateTime(2026, 1, 5), recurrence: RecurrenceType.weekly);
      final occ = expandExpenseOccurrencesBetween(exp, DateTime(2026, 1, 5), DateTime(2026, 1, 26));
      expect(occ.length, 4);
      expect(occ.last.date, DateTime(2026, 1, 26));
    });

    test('monthly clamps Feb and retains anchor 31', () {
      final exp = _exp(debitDate: DateTime(2026, 1, 31), recurrence: RecurrenceType.monthly, anchorDay: 31);
      final occ = expandExpenseOccurrencesBetween(exp, DateTime(2026, 1, 1), DateTime(2026, 5, 31));
      expect(occ.map((o) => o.date.day), [31, 28, 31, 30, 31]);
    });

    test('bimonthly every 2 months', () {
      final exp = _exp(debitDate: DateTime(2026, 1, 15), recurrence: RecurrenceType.bimonthly);
      final occ = expandExpenseOccurrencesBetween(exp, DateTime(2026, 1, 1), DateTime(2026, 7, 31));
      expect(occ.map((o) => o.date.month), [1, 3, 5, 7]);
    });

    test('trimonthly every 3 months', () {
      final exp = _exp(debitDate: DateTime(2026, 1, 15), recurrence: RecurrenceType.trimonthly);
      final occ = expandExpenseOccurrencesBetween(exp, DateTime(2026, 1, 1), DateTime(2026, 12, 31));
      expect(occ.length, 4);
      expect(occ.map((o) => o.date.month), [1, 4, 7, 10]);
    });

    test('halfyearly every 6 months', () {
      final exp = _exp(debitDate: DateTime(2026, 1, 15), recurrence: RecurrenceType.halfyearly);
      final occ = expandExpenseOccurrencesBetween(exp, DateTime(2026, 1, 1), DateTime(2027, 12, 31));
      expect(occ.length, 4);
      expect(occ[0].date, DateTime(2026, 1, 15));
      expect(occ[1].date, DateTime(2026, 7, 15));
      expect(occ[2].date, DateTime(2027, 1, 15));
    });

    test('yearly once per year', () {
      final exp = _exp(debitDate: DateTime(2026, 6, 15), recurrence: RecurrenceType.yearly);
      final occ = expandExpenseOccurrencesBetween(exp, DateTime(2026, 1, 1), DateTime(2029, 12, 31));
      expect(occ.length, 4);
      expect(occ.map((o) => o.date.year), [2026, 2027, 2028, 2029]);
    });

    test('biyearly every 24 months', () {
      final exp = _exp(debitDate: DateTime(2026, 6, 15), recurrence: RecurrenceType.biyearly);
      final occ = expandExpenseOccurrencesBetween(exp, DateTime(2026, 1, 1), DateTime(2030, 12, 31));
      expect(occ.length, 3);
      expect(occ.map((o) => o.date.year), [2026, 2028, 2030]);
    });
  });

  group('Recurrence date edge cases', () {
    test('Feb 29 anchor propagates correctly in leap vs non-leap', () {
      final exp = _exp(debitDate: DateTime(2024, 2, 29), recurrence: RecurrenceType.yearly, anchorDay: 29);
      final occ = expandExpenseOccurrencesBetween(exp, DateTime(2024, 1, 1), DateTime(2028, 12, 31));
      // 2024-02-29, 2025-02-28 clamped, 2026-02-28, 2027-02-28, 2028-02-29
      expect(occ[0].date, DateTime(2024, 2, 29));
      expect(occ[1].date, DateTime(2025, 2, 28));
      expect(occ[2].date, DateTime(2026, 2, 28));
      expect(occ[3].date, DateTime(2027, 2, 28));
      expect(occ[4].date, DateTime(2028, 2, 29));
    });

    test('Jan 31 -> Feb 28 -> Mar 31 monthly cycle preserves anchor', () {
      var date = DateTime(2026, 1, 31);
      for (final expected in [DateTime(2026, 2, 28), DateTime(2026, 3, 31), DateTime(2026, 4, 30)]) {
        date = RecurrenceType.monthly.nextOccurrenceAfter(date, anchorDay: 31);
        expect(date, expected);
      }
    });

    test('endDate is inclusive to end of day', () {
      final exp = _exp(debitDate: DateTime(2026, 1, 15), recurrence: RecurrenceType.monthly, endDate: DateTime(2026, 3, 15));
      final occ = expandExpenseOccurrencesBetween(exp, DateTime(2026, 1, 1), DateTime(2026, 12, 31));
      expect(occ.length, 3);
      expect(occ.last.date, DateTime(2026, 3, 15));
    });

    test('occurrence ∈ période de récurrence invariant', () {
      final exp = _exp(debitDate: DateTime(2026, 1, 10), recurrence: RecurrenceType.monthly, endDate: DateTime(2026, 6, 10));
      final from = DateTime(2026, 1, 1);
      final to = DateTime(2026, 12, 31);
      final occ = expandExpenseOccurrencesBetween(exp, from, to);
      for (final o in occ) {
        expect(o.date.isBefore(from), isFalse, reason: 'occurrence before range');
        expect(o.date.isAfter(to), isFalse, reason: 'occurrence after range');
        // also within recurrence window
        expect(o.date.isBefore(exp.debitDate), isFalse);
        if (exp.endOfEndDate != null) expect(o.date.isAfter(exp.endOfEndDate!), isFalse);
      }
    });

    test('changement de mois décembre -> janvier génère correctement', () {
      final exp = _exp(debitDate: DateTime(2025, 12, 15), recurrence: RecurrenceType.monthly);
      final dec = expandExpenseOccurrences(_exp(debitDate: DateTime(2025, 12, 15), recurrence: RecurrenceType.monthly), const Period(year: 2025, month: 12));
      final jan = expandExpenseOccurrences(exp, const Period(year: 2026, month: 1));
      // Need to expand for jan period - but debitDate is Dec 15, so Jan 15 should appear
      expect(jan.length, 1);
      expect(jan.single.date, DateTime(2026, 1, 15));
      expect(dec.single.date, DateTime(2025, 12, 15));
    });

    test('debitedOccurrences affect isDebited per date', () {
      final exp = _exp(
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
        debited: ['2026-01-15', '2026-03-15'],
      );
      final occ = expandExpenseOccurrencesBetween(exp, DateTime(2026, 1, 1), DateTime(2026, 4, 30));
      expect(occ[0].isDebited, isTrue);
      expect(occ[1].isDebited, isFalse);
      expect(occ[2].isDebited, isTrue);
      expect(occ[3].isDebited, isFalse);
    });

    test('modification future ne modifie pas historique (split invariants)', () {
      // Simulated via RecurringExpenseVersioning split semantics: previous keeps history
      final original = _exp(id: 'rid', debitDate: DateTime(2026, 1, 15), recurrence: RecurrenceType.monthly, debited: ['2026-01-15', '2026-02-15']);
      final updated = _exp(id: 'rid', debitDate: DateTime(2026, 3, 15), recurrence: RecurrenceType.monthly, debited: []);
      // After split at 2026-03-15, previous endDate should be 2026-03-14 and contain only earlier debited
      // This is validated in dedicated versioning tests, here we just verify occurrence generation respects endDate
      final prevEnd = DateTime(2026, 3, 14);
      final previous = original.copyWith(endDate: prevEnd, debitedOccurrences: ['2026-01-15', '2026-02-15']);
      final occPrev = expandExpenseOccurrencesBetween(previous, DateTime(2026, 1, 1), DateTime(2026, 12, 31));
      final occNext = expandExpenseOccurrencesBetween(updated.copyWith(debitDate: DateTime(2026, 3, 15)), DateTime(2026, 1, 1), DateTime(2026, 12, 31));
      // No overlap and history preserved
      expect(occPrev.any((o) => o.date.isAfter(prevEnd)), isFalse);
      expect(occNext.any((o) => o.date.isBefore(DateTime(2026, 3, 15))), isFalse);
      expect(occPrev.length, 2);
    });
  });

  group('addMonthsClamped utility', () {
    test('clamps day 31 to Feb 28 non-leap', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1, anchorDay: 31), DateTime(2026, 2, 28));
    });
    test('preserves anchor 31 to Mar 31', () {
      expect(addMonthsClamped(DateTime(2026, 2, 28), 1, anchorDay: 31), DateTime(2026, 3, 31));
    });
    test('handles negative months', () {
      expect(addMonthsClamped(DateTime(2026, 3, 31), -1, anchorDay: 31), DateTime(2026, 2, 28));
    });
    test('leap year Feb 29 anchor', () {
      expect(addMonthsClamped(DateTime(2023, 1, 29), 1, anchorDay: 29), DateTime(2023, 2, 28));
      expect(addMonthsClamped(DateTime(2024, 1, 29), 1, anchorDay: 29), DateTime(2024, 2, 29));
    });
  });
}
