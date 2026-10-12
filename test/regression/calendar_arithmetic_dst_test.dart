import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/calculators/recurring_expense_versioning.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';
import '../helpers.dart';

/// Business dates are calendar days. `DateTime.add/subtract(Duration(days: 1))`
/// moves by 24 *elapsed hours*, which is not one calendar day across a DST
/// change: in Europe/Paris, 30 March 2026 00:00 minus 24 h is 28 March 23:00.
///
/// These tests only discriminate when the suite runs in a timezone with DST.
/// CI runs in UTC, where the old code was also correct; run them locally with
///   TZ=Europe/Paris flutter test test/regression/calendar_arithmetic_dst_test.dart
///   TZ=America/New_York flutter test test/regression/calendar_arithmetic_dst_test.dart
/// Europe/Paris spring-forward 2026: 29 March. America/New_York: 8 March.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Expense recurring({
    required DateTime debitDate,
    DateTime? endDate,
    int? anchor,
  }) => Fixtures.expense(
    id: 'r1',
    accountId: 'a1',
    categoryId: 'c1',
    debitDate: debitDate,
    endDate: endDate,
    recurrence: RecurrenceType.monthly,
    recurrenceAnchorDay: anchor,
  );

  group('Expense.endDateExclusive', () {
    for (final end in [
      DateTime(2026, 3, 29), // Europe/Paris spring-forward day
      DateTime(2026, 3, 8), // America/New_York spring-forward day
      DateTime(2026, 10, 25), // Europe/Paris fall-back day
      DateTime(2026, 11, 1), // America/New_York fall-back day
      DateTime(2026, 2, 28),
      DateTime(2028, 2, 29),
      DateTime(2026, 12, 31),
    ]) {
      test('is midnight of the day after $end', () {
        final exclusive = recurring(
          debitDate: DateTime(2026, 1, 1),
          endDate: end,
        ).endDateExclusive;

        expect(exclusive, DateTime(end.year, end.month, end.day + 1));
        expect(exclusive!.hour, 0);
      });
    }
  });

  group('RecurringExpenseVersioning.split', () {
    for (final effective in [
      DateTime(2026, 3, 30), // day after Europe/Paris spring-forward
      DateTime(2026, 3, 9), // day after America/New_York spring-forward
      DateTime(2026, 10, 26),
      DateTime(2026, 11, 2),
      DateTime(2026, 3, 1),
    ]) {
      test('ends the previous version the calendar day before $effective', () {
        final original = recurring(debitDate: DateTime(2025, 12, 1));

        final version = const RecurringExpenseVersioning().split(
          original: original,
          updated: original.copyWith(amount: 99),
          effectiveDate: effective,
        );

        expect(
          version.previous.endDate,
          DateTime(effective.year, effective.month, effective.day - 1),
        );
        expect(version.next.debitDate, effective);
      });
    }
  });

  group('ExpensesService.deleteFutureOccurrences', () {
    late OfflineAwareExpenseFirestore firestore;
    late ExpensesService service;

    setUp(() {
      firestore = OfflineAwareExpenseFirestore()..online = true;
      service = ExpensesService(
        expenseFirestore: firestore,
        analytics: AnalyticsService(),
      );
    });

    for (final occurrence in [
      DateTime(2026, 3, 30), // day after Europe/Paris spring-forward
      DateTime(2026, 10, 26), // day after Europe/Paris fall-back
    ]) {
      test('truncates the series the day before $occurrence', () async {
        final series = recurring(
          debitDate: DateTime(2026, 1, occurrence.day),
          anchor: occurrence.day,
        );
        await service.createExpense(series);

        final result = await service.deleteFutureOccurrences(
          expense: series,
          occurrenceDate: occurrence,
        );

        expect(result, isTrue);
        // Assert on the acknowledged write, not on service.getExpenseById: a
        // recurring mutation intentionally drops the account's period cache
        // (ExpensePeriodCache.optimisticUpdateExpense), and the optimistic
        // shield is released once Firestore acknowledges the update
        // (ExpenseSyncHandler.update). The persisted endDate is therefore the
        // only observation point that stays valid online and offline.
        expect(
          firestore.server.single.endDate,
          DateTime(occurrence.year, occurrence.month, occurrence.day - 1),
        );
      });
    }
  });
}
