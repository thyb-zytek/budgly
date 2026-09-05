import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Period edge cases', () {
    test('addMonths handles large negative offsets across multiple years', () {
      const period = Period(year: 2026, month: 8);
      expect(period.addMonths(-25), const Period(year: 2024, month: 7));
    });

    test('addMonths handles large positive offsets across multiple years', () {
      const period = Period(year: 2026, month: 8);
      expect(period.addMonths(25), const Period(year: 2028, month: 9));
    });

    test('totalWeekends handles a month ending on Saturday', () {
      const period = Period(year: 2026, month: 10);
      expect(period.totalWeekends(), 5);
    });

    test('contains includes the final millisecond of the month', () {
      const period = Period(year: 2026, month: 2);
      expect(period.contains(DateTime(2026, 2, 28, 23, 59, 59, 999)), isTrue);
    });
  });
}
