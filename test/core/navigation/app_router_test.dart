import 'package:budgly/src/core/navigation/app_router.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a valid period from route query parameters', () {
    expect(
      AppRouter.parsePeriod(Uri.parse('/overview?year=2026&month=9')),
      const Period(year: 2026, month: 9),
    );
  });

  test(
    'falls back to current period for missing or invalid route parameters',
    () {
      final expected = Period.current();
      expect(AppRouter.parsePeriod(Uri.parse('/overview')), expected);
      expect(
        AppRouter.parsePeriod(Uri.parse('/overview?year=2026&month=13')),
        expected,
      );
      expect(
        AppRouter.parsePeriod(Uri.parse('/overview?year=2026&month=0')),
        expected,
        reason: 'month must be in the 1-12 range',
      );
      expect(
        AppRouter.parsePeriod(Uri.parse('/overview?year=not-a-number&month=9')),
        expected,
      );
      expect(
        AppRouter.parsePeriod(Uri.parse('/overview?year=2026')),
        expected,
        reason: 'month alone missing must not produce a half-parsed period',
      );
    },
  );
}
