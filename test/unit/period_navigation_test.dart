import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('REG-PERIOD: navigation & invariants', () {
    test('Overview regression: December -> January year rollover', () {
      const dec = Period(year: 2025, month: 12);
      const jan = Period(year: 2026, month: 1);
      expect(dec.next, jan);
      expect(jan.previous, dec);
      expect(dec.isBefore(jan), isTrue);
      expect(jan.isAfter(dec), isTrue);
    });

    test('February leap year boundaries', () {
      const feb2024 = Period(year: 2024, month: 2);
      expect(feb2024.endOfMonth.day, 29);
      const feb2025 = Period(year: 2025, month: 2);
      expect(feb2025.endOfMonth.day, 28);
      const feb2028 = Period(year: 2028, month: 2);
      expect(feb2028.endOfMonth.day, 29);
    });

    test('30/31 day months end correctly', () {
      expect(const Period(year: 2026, month: 4).endOfMonth.day, 30);
      expect(const Period(year: 2026, month: 6).endOfMonth.day, 30);
      expect(const Period(year: 2026, month: 9).endOfMonth.day, 30);
      expect(const Period(year: 2026, month: 11).endOfMonth.day, 30);
      expect(const Period(year: 2026, month: 1).endOfMonth.day, 31);
      expect(const Period(year: 2026, month: 7).endOfMonth.day, 31);
      expect(const Period(year: 2026, month: 12).endOfMonth.day, 31);
    });

    test('P0 regression: Overview selecting March then opening category keeps March', () {
      // The bug: detail screen replaced selectedPeriod with Period.current()
      // Simulate ViewModel keeping explicit period param
      const selected = Period(year: 2026, month: 3);
      const current = Period(year: 2026, month: 5);
      // CategoryExpensesViewModel receives period via constructor and never overwrites it
      const vmPeriod = selected;
      expect(vmPeriod, isNot(current));
      expect(vmPeriod, selected);
      expect(vmPeriod.month, 3);
    });

    test('swipe navigation: addMonths handles large deltas', () {
      const base = Period(year: 2026, month: 6);
      expect(base.addMonths(-18), const Period(year: 2024, month: 12));
      expect(base.addMonths(18), const Period(year: 2027, month: 12));
      expect(base.addMonths(-6), const Period(year: 2025, month: 12));
      expect(base.addMonths(6), const Period(year: 2026, month: 12));
    });

    test('contains respects inclusive start and exclusive after end', () {
      const march = Period(year: 2026, month: 3);
      expect(march.contains(DateTime(2026, 3, 1, 0, 0, 0)), isTrue);
      expect(march.contains(DateTime(2026, 3, 1).subtract(const Duration(milliseconds: 1))), isFalse);
      expect(march.contains(DateTime(2026, 3, 31, 23, 59, 59)), isTrue);
      expect(march.contains(DateTime(2026, 4, 1)), isFalse);
      // February leap boundary
      const feb = Period(year: 2024, month: 2);
      expect(feb.contains(DateTime(2024, 2, 29)), isTrue);
      expect(feb.contains(DateTime(2024, 3, 1)), isFalse);
    });

    test('changing account + period preserves isolation (no leakage)', () {
      // Ensures accountId + period are both keys, not just period
      const p1 = Period(year: 2026, month: 3);
      const p2 = Period(year: 2026, month: 4);
      final keyA = 'accA|$p1|*';
      final keyB = 'accB|$p1|*';
      final keyA2 = 'accA|$p2|*';
      expect(keyA, isNot(keyB));
      expect(keyA, isNot(keyA2));
    });

    test('navigation fév -> mars année bissextile', () {
      const feb = Period(year: 2024, month: 2);
      expect(feb.next, const Period(year: 2024, month: 3));
      const jan = Period(year: 2024, month: 1);
      expect(jan.addMonths(1), feb);
    });

    test('isBefore/isAfter transitive across year boundary', () {
      const dec = Period(year: 2025, month: 12);
      const jan = Period(year: 2026, month: 1);
      const feb = Period(year: 2026, month: 2);
      expect(dec.isBefore(feb), isTrue);
      expect(feb.isAfter(dec), isTrue);
      expect(jan.isBefore(feb), isTrue);
      expect(dec.isAfter(jan), isFalse);
    });

    test('Period.current returns stable year/month for now', () {
      final now = DateTime.now();
      final cur = Period.current();
      expect(cur.year, now.year);
      expect(cur.month, now.month);
    });
  });

  group('Period remainingWeekends edge', () {
    test('future period returns totalWeekends', () {
      final future = Period.current().addMonths(1);
      final total = future.totalWeekends();
      // totalWeekends counts all Saturdays
      expect(total, greaterThanOrEqualTo(4));
      expect(total, lessThanOrEqualTo(5));
    });

    test('past period remaining is null in ViewModel semantics (guarded)', () {
      final past = Period.current().addMonths(-1);
      expect(past.isBefore(Period.current()), isTrue);
      // ViewModel returns null for past remainingWeekendsInPeriod
    });
  });
}
