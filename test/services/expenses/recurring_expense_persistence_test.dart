import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/expenses/expense_period_cache.dart';
import 'package:budgly/src/services/expenses/recurring_expense_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

Expense _expense(String id, DateTime date) => Expense(
  id: id,
  accountId: 'a1',
  categoryId: 'c1',
  name: 'Rent',
  amount: 100,
  debitDate: date,
  recurrence: RecurrenceType.monthly,
  recurrenceAnchorDay: date.day,
);

void main() {
  late OfflineAwareExpenseFirestore firestore;
  late ExpensePeriodCache cache;
  late RecurringExpensePersistence persistence;
  late List<String> rejected;

  setUp(() {
    firestore = OfflineAwareExpenseFirestore();
    cache = ExpensePeriodCache();
    rejected = [];
    persistence = RecurringExpensePersistence(
      firestore: firestore,
      periodData: cache,
      onWriteRejected: rejected.add,
    );
  });

  test('returns immediately with the next identity, even offline', () async {
    final result = await persistence
        .split(
          previous: _expense('e1', DateTime(2026, 1, 15)),
          next: _expense('e2', DateTime(2026, 3, 15)),
        )
        .timeout(const Duration(seconds: 2));

    expect(result.id, 'e2');
    expect(firestore.pendingWriteCount, 1);
    expect(rejected, isEmpty);
  });

  test('the batch is delivered atomically by Firestore once online', () async {
    await persistence.split(
      previous: _expense('e1', DateTime(2026, 1, 15)),
      next: _expense('e2', DateTime(2026, 3, 15)),
    );

    firestore.goOnline();
    await Future<void>.delayed(Duration.zero);

    expect(firestore.server.map((e) => e.id), unorderedEquals(['e1', 'e2']));
  });

  test(
    'allocates a deterministic identity when the next version has none',
    () async {
      final next = Expense(
        accountId: 'a1',
        categoryId: 'c1',
        name: 'Rent',
        amount: 100,
        debitDate: DateTime(2026, 3, 15),
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: 15,
      );

      final result = await persistence.split(
        previous: _expense('e1', DateTime(2026, 1, 15)),
        next: next,
      );
      firestore.goOnline();
      await Future<void>.delayed(Duration.zero);

      expect(result.id, isNotNull);
      expect(firestore.server.map((e) => e.id), contains(result.id));
    },
  );

  test('a rejected batch is reported for reconciliation', () async {
    firestore
      ..online = true
      ..rejectWrites = true;

    await persistence.split(
      previous: _expense('e1', DateTime(2026, 1, 15)),
      next: _expense('e2', DateTime(2026, 3, 15)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(rejected, ['a1']);
    expect(firestore.server, isEmpty);
  });

  test('rejects a split without a previous expense id', () async {
    final previous = Expense(
      accountId: 'a1',
      categoryId: 'c1',
      name: 'Rent',
      amount: 100,
      debitDate: DateTime(2026, 1, 15),
      recurrence: RecurrenceType.monthly,
      recurrenceAnchorDay: 15,
    );

    expect(
      () => persistence.split(
        previous: previous,
        next: _expense('e2', DateTime(2026, 3, 15)),
      ),
      throwsStateError,
    );
  });
}
