import 'package:budgly/src/models/budget/calendar_date_range.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence_exception.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';
import '../../helpers.dart';

/// Service-level orchestration of recurring series, against a fake that
/// acknowledges writes like the real SDK does once online.
///
/// The building blocks are covered elsewhere (RecurringExpenseVersioning,
/// RecurringExpensePersistence, ExpenseFirestore.splitRecurringExpense); these
/// tests pin how ExpensesService combines them, in particular around the
/// Europe/Paris and America/New_York DST changes (see
/// test/regression/calendar_arithmetic_dst_test.dart for how to run them under
/// another timezone).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineAwareExpenseFirestore firestore;
  late ExpensesService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
    firestore = OfflineAwareExpenseFirestore()..online = true;
    service = ExpensesService(
      expenseFirestore: firestore,
      analytics: AnalyticsService(),
    );
  });

  tearDown(() async {
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Expense series({
    DateTime? debitDate,
    int? anchor,
    List<ExpenseOccurrenceException> exceptions = const [],
    List<String> debited = const [],
  }) => Fixtures.expense(
    id: 'r1',
    accountId: 'a1',
    categoryId: 'c1',
    amount: 50,
    debitDate: debitDate ?? DateTime(2026, 1, 15),
    recurrence: RecurrenceType.monthly,
    recurrenceAnchorDay: anchor,
    debitedOccurrences: debited,
  ).copyWith(occurrenceExceptions: exceptions);

  Future<Expense> seed(Expense expense) async {
    final created = await service.createExpense(expense);
    await settle();
    return created;
  }

  Expense serverExpense(String id) =>
      firestore.server.firstWhere((expense) => expense.id == id);

  group('debiting edited recurring occurrences', () {
    test('a single-occurrence edit can be debited and unmarked', () async {
      final original = await seed(series());
      final edited = await service.modifySingleOccurrence(
        original: original,
        occurrenceDate: DateTime(2026, 3, 15),
        override: original.copyWith(amount: 99),
      );
      await settle();

      final debited = await service.markOccurrenceDebited(
        edited,
        DateTime(2026, 3, 15),
      );
      await settle();

      expect(debited.isDebitedAt(DateTime(2026, 3, 15)), isTrue);
      expect(debited.exceptionAt(DateTime(2026, 3, 15))!.isDebited, isTrue);
      expect(
        expandExpenseOccurrencesBetween(
          debited,
          CalendarDateRange(
            start: DateTime(2026, 3, 1),
            endExclusive: DateTime(2026, 4, 1),
          ),
        ).single.isDebited,
        isTrue,
      );

      final pending = await service.unmarkOccurrenceDebited(
        debited,
        DateTime(2026, 3, 15),
      );
      expect(pending.isDebitedAt(DateTime(2026, 3, 15)), isFalse);
      expect(pending.exceptionAt(DateTime(2026, 3, 15))!.isDebited, isFalse);
    });

    test('an occurrence in a future split can be debited', () async {
      final original = await seed(series());
      final next = await service.modifyFutureOccurrences(
        original: original,
        updated: original.copyWith(amount: 99),
        effectiveDate: DateTime(2026, 3, 15),
      );
      await settle();

      final debited = await service.markOccurrenceDebited(
        next,
        DateTime(2026, 3, 15),
      );
      await settle();

      expect(debited.isDebitedAt(DateTime(2026, 3, 15)), isTrue);
    });

    test('an occurrence edited before a future split is debited through its '
        'rekeyed exception', () async {
      final original = await seed(series());
      final edited = await service.modifySingleOccurrence(
        original: original,
        occurrenceDate: DateTime(2026, 4, 15),
        override: original.copyWith(amount: 7),
      );
      await settle();

      final next = await service.modifyFutureOccurrences(
        original: edited,
        updated: edited.copyWith(amount: 99),
        effectiveDate: DateTime(2026, 3, 15),
      );
      await settle();

      // The split gives the series a new id: the carried exception must
      // follow it, override included, or debiting never finds it again.
      final carried = next.exceptionAt(DateTime(2026, 4, 15));
      expect(carried, isNotNull);
      expect(carried!.key, '${next.id}@2026-04-15');
      expect(carried.amount, 7);

      final debited = await service.markOccurrenceDebited(
        next,
        DateTime(2026, 4, 15),
      );
      await settle();

      expect(debited.isDebitedAt(DateTime(2026, 4, 15)), isTrue);
      expect(debited.exceptionAt(DateTime(2026, 4, 15))!.isDebited, isTrue);
    });

    test('an exception left before the split does not block debiting a later '
        'occurrence', () async {
      final original = await seed(series());
      final edited = await service.modifySingleOccurrence(
        original: original,
        occurrenceDate: DateTime(2026, 2, 15),
        override: original.copyWith(amount: 11),
      );
      await settle();

      final next = await service.modifyFutureOccurrences(
        original: edited,
        updated: edited.copyWith(amount: 99),
        effectiveDate: DateTime(2026, 3, 15),
      );
      await settle();

      final debited = await service.markOccurrenceDebited(
        next,
        DateTime(2026, 3, 15),
      );
      await settle();

      expect(debited.isDebitedAt(DateTime(2026, 3, 15)), isTrue);
      // The earlier edited occurrence still carries its override.
      expect(
        serverExpense('r1').exceptionAt(DateTime(2026, 2, 15))!.amount,
        11,
      );
    });
  });

  group('updateRecurringExpenseFromOccurrence', () {
    test(
      'a mid-series change splits the series at the effective day',
      () async {
        final original = await seed(series());

        final next = await service.updateRecurringExpenseFromOccurrence(
          original: original,
          updated: original.copyWith(amount: 99),
          effectiveDate: DateTime(2026, 3, 15),
        );
        await settle();

        expect(next.id, isNot('r1'));
        expect(next.amount, 99);
        expect(next.debitDate, DateTime(2026, 3, 15));
        expect(serverExpense('r1').endDate, DateTime(2026, 3, 14));
        expect(serverExpense('r1').amount, 50);
        expect(serverExpense(next.id!).amount, 99);
        expect(firestore.server, hasLength(2));
      },
    );

    for (final effective in [
      DateTime(2026, 3, 30), // day after the Europe/Paris spring-forward
      DateTime(2026, 10, 26), // day after the Europe/Paris fall-back
    ]) {
      test(
        'the previous version ends the calendar day before $effective',
        () async {
          final original = await seed(
            series(
              debitDate: DateTime(2026, 1, effective.day),
              anchor: effective.day,
            ),
          );

          await service.updateRecurringExpenseFromOccurrence(
            original: original,
            updated: original.copyWith(amount: 99),
            effectiveDate: effective,
          );
          await settle();

          expect(
            serverExpense('r1').endDate,
            DateTime(effective.year, effective.month, effective.day - 1),
          );
        },
      );
    }

    test(
      'a change effective on the first day updates the series in place',
      () async {
        final original = await seed(series());

        final result = await service.updateRecurringExpenseFromOccurrence(
          original: original,
          updated: original.copyWith(amount: 99),
          effectiveDate: DateTime(2026, 1, 15),
        );
        await settle();

        expect(result.id, 'r1');
        expect(firestore.server, hasLength(1));
        expect(serverExpense('r1').amount, 99);
      },
    );

    test('exceptions are partitioned between the two versions', () async {
      final original = await seed(
        series(
          exceptions: const [
            ExpenseOccurrenceException(key: 'r1@2026-02-15', amount: 5),
            ExpenseOccurrenceException(key: 'r1@2026-04-15', amount: 7),
          ],
        ),
      );

      final next = await service.updateRecurringExpenseFromOccurrence(
        original: original,
        updated: original.copyWith(amount: 99),
        effectiveDate: DateTime(2026, 3, 15),
      );
      await settle();

      expect(serverExpense('r1').occurrenceExceptions.map((e) => e.key), [
        'r1@2026-02-15',
      ]);
      expect(serverExpense(next.id!).occurrenceExceptions.map((e) => e.key), [
        '${next.id}@2026-04-15',
      ]);
    });

    test('a non-recurring original is simply updated', () async {
      final oneOff = await seed(
        Fixtures.expense(
          id: 'e1',
          accountId: 'a1',
          categoryId: 'c1',
          amount: 10,
          debitDate: DateTime(2026, 3, 15),
        ),
      );

      final result = await service.updateRecurringExpenseFromOccurrence(
        original: oneOff,
        updated: oneOff.copyWith(amount: 20),
        effectiveDate: DateTime(2026, 3, 15),
      );
      await settle();

      expect(result.id, 'e1');
      expect(serverExpense('e1').amount, 20);
    });

    test('modifyFutureOccurrences is the same split', () async {
      final original = await seed(series());

      final next = await service.modifyFutureOccurrences(
        original: original,
        updated: original.copyWith(amount: 99),
        effectiveDate: DateTime(2026, 3, 15),
      );
      await settle();

      expect(next.debitDate, DateTime(2026, 3, 15));
      expect(serverExpense('r1').endDate, DateTime(2026, 3, 14));
    });
  });

  group('deleteFutureOccurrences', () {
    test('drops exceptions that apply from the target day on, keeps earlier ones', () async {
      final original = await seed(
        series(
          exceptions: [
            const ExpenseOccurrenceException(key: 'r1@2026-02-15', amount: 5),
            // Source before the target, but moved after it: no longer applies.
            ExpenseOccurrenceException(
              key: 'r1@2026-03-15',
              debitDate: DateTime(2026, 4, 20),
            ),
            const ExpenseOccurrenceException(key: 'r1@2026-05-15', amount: 7),
          ],
        ),
      );

      final deleted = await service.deleteFutureOccurrences(
        expense: original,
        occurrenceDate: DateTime(2026, 4, 15),
      );
      await settle();

      expect(deleted, isTrue);
      final persisted = serverExpense('r1');
      expect(persisted.endDate, DateTime(2026, 4, 14));
      expect(persisted.occurrenceExceptions.map((e) => e.key), [
        'r1@2026-02-15',
      ]);
    });

    test(
      'keeps the debited marks before the target and drops the others',
      () async {
        final original = await seed(
          series(debited: const ['2026-02-15', '2026-04-15', '2026-05-15']),
        );

        await service.deleteFutureOccurrences(
          expense: original,
          occurrenceDate: DateTime(2026, 4, 15),
        );
        await settle();

        expect(serverExpense('r1').debitedOccurrences, ['2026-02-15']);
      },
    );

    test('a non-recurring expense is deleted', () async {
      final oneOff = await seed(
        Fixtures.expense(
          id: 'e1',
          accountId: 'a1',
          categoryId: 'c1',
          debitDate: DateTime(2026, 3, 15),
        ),
      );

      final deleted = await service.deleteFutureOccurrences(
        expense: oneOff,
        occurrenceDate: DateTime(2026, 3, 15),
      );
      await settle();

      expect(deleted, isTrue);
      expect(firestore.server, isEmpty);
    });
  });

  group('debited marks', () {
    test(
      'unmarkOccurrenceDebited removes the mark of a recurring occurrence',
      () async {
        final original = await seed(series(debited: const ['2026-02-15']));

        final result = await service.unmarkOccurrenceDebited(
          original,
          DateTime(2026, 2, 15),
        );
        await settle();

        expect(result.debitedOccurrences, isEmpty);
        expect(serverExpense('r1').debitedOccurrences, isEmpty);
      },
    );

    test(
      'unmarkOccurrenceDebited is a no-op for an occurrence that is not marked',
      () async {
        final original = await seed(series(debited: const ['2026-02-15']));

        final result = await service.unmarkOccurrenceDebited(
          original,
          DateTime(2026, 3, 15),
        );

        expect(identical(result, original), isTrue);
      },
    );

    test('unmarkOccurrenceDebited un-debits a non-recurring expense', () async {
      final oneOff = await seed(
        Fixtures.expense(
          id: 'e1',
          accountId: 'a1',
          categoryId: 'c1',
          debitDate: DateTime(2026, 3, 15),
          isDebited: true,
        ),
      );

      final result = await service.unmarkOccurrenceDebited(
        oneOff,
        DateTime(2026, 3, 15),
      );
      await settle();

      expect(result.isDebited, isFalse);
      expect(serverExpense('e1').isDebited, isFalse);
    });

    test('toggleOccurrenceDebited flips the state both ways', () async {
      final original = await seed(series());

      final marked = await service.toggleOccurrenceDebited(
        original,
        DateTime(2026, 2, 15),
      );
      expect(marked.debitedOccurrences, ['2026-02-15']);

      final unmarked = await service.toggleOccurrenceDebited(
        marked,
        DateTime(2026, 2, 15),
      );
      expect(unmarked.debitedOccurrences, isEmpty);
    });
  });

  group('moveOccurrenceToDate', () {
    test('moves one occurrence of a series through an exception and keeps its override', () async {
      final original = await seed(
        series(
          exceptions: const [
            ExpenseOccurrenceException(
              key: 'r1@2026-03-15',
              amount: 5,
              name: 'Special',
            ),
          ],
        ),
      );

      final moved = await service.moveOccurrenceToDate(
        original,
        DateTime(2026, 3, 15),
        DateTime(2026, 3, 29),
        markDebited: true,
      );
      await settle();

      final exception = serverExpense('r1').occurrenceExceptions
          .singleWhere((e) => e.key == 'r1@2026-03-15');
      expect(exception.debitDate, DateTime(2026, 3, 29));
      expect(exception.isDebited, isTrue);
      expect(exception.amount, 5);
      expect(exception.name, 'Special');
      expect(moved.debitDate, original.debitDate);
    });

    test(
      'the series itself is untouched: only the keyed occurrence changes',
      () async {
        final original = await seed(series());

        await service.moveOccurrenceToDate(
          original,
          DateTime(2026, 3, 15),
          DateTime(2026, 3, 20),
          markDebited: false,
        );
        await settle();

        final persisted = serverExpense('r1');
        expect(persisted.debitDate, DateTime(2026, 1, 15));
        expect(persisted.endDate, isNull);
        expect(persisted.occurrenceExceptions, hasLength(1));
      },
    );

    test('a non-recurring expense simply changes its date', () async {
      final oneOff = await seed(
        Fixtures.expense(
          id: 'e1',
          accountId: 'a1',
          categoryId: 'c1',
          debitDate: DateTime(2026, 3, 15),
        ),
      );

      final moved = await service.moveOccurrenceToDate(
        oneOff,
        DateTime(2026, 3, 15),
        DateTime(2026, 3, 29),
        markDebited: true,
      );
      await settle();

      expect(moved.debitDate, DateTime(2026, 3, 29));
      expect(serverExpense('e1').debitDate, DateTime(2026, 3, 29));
      expect(serverExpense('e1').isDebited, isTrue);
    });
  });

  group('legacy queued operations', () {
    test('an update queued by an older build is delivered', () async {
      final original = await seed(series());
      service.registerSyncHandler(testSyncManager);
      await testSyncQueue.enqueue(
        id: 'expense:update:r1',
        type: 'expenses',
        operation: 'update',
        payload: original.copyWith(amount: 77).toJson(),
      );

      await testSyncManager.flush(forceRetry: true);

      expect(serverExpense('r1').amount, 77);
      expect(await testSyncQueue.all(), isEmpty);
    });

    test('a delete queued by an older build is delivered', () async {
      final original = await seed(series());
      service.registerSyncHandler(testSyncManager);
      await testSyncQueue.enqueue(
        id: 'expense:delete:r1',
        type: 'expenses',
        operation: 'delete',
        payload: {'id': original.id},
      );

      await testSyncManager.flush(forceRetry: true);

      expect(firestore.server, isEmpty);
      expect(await testSyncQueue.all(), isEmpty);
    });

    test(
      'an unknown operation is reported as a failure, not dropped',
      () async {
        service.registerSyncHandler(testSyncManager);
        await testSyncQueue.enqueue(
          id: 'expense:weird:r1',
          type: 'expenses',
          operation: 'weird',
          payload: {'id': 'r1'},
        );

        await testSyncManager.flush(forceRetry: true);

        expect(await testSyncQueue.all(), hasLength(1));
      },
    );
  });
}
