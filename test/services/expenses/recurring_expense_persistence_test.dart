import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/expenses/expense_period_cache.dart';
import 'package:budgly/src/services/expenses/recurring_expense_persistence.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExpenseFirestore extends ExpenseFirestore {
  Expense? created;
  Expense? updated;
  bool returnNull = false;
  bool throwOnSplit = false;

  @override
  Future<Expense?> splitRecurringExpense({
    required Expense previous,
    required Expense next,
  }) async {
    updated = previous;
    created = next;
    if (throwOnSplit) throw StateError('offline');
    if (returnNull) return null;
    return next.copyWith(id: 'server-next');
  }
}

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
  late _FakeExpenseFirestore firestore;
  late ExpensePeriodCache cache;
  late RecurringExpensePersistence persistence;

  setUp(() {
    firestore = _FakeExpenseFirestore();
    cache = ExpensePeriodCache();
    persistence = RecurringExpensePersistence(
      firestore: firestore,
      periodData: cache,
    );
  });

  test('returns server identity when split is committed', () async {
    final result = await persistence.split(
      previous: _expense('e1', DateTime(2026, 1, 15)),
      next: _expense('e2', DateTime(2026, 3, 15)),
    );

    expect(result.id, 'server-next');
    expect(firestore.updated?.id, 'e1');
    expect(firestore.created?.id, 'e2');
  });

  test('creates a local identity when Firestore returns null', () async {
    firestore.returnNull = true;

    final result = await persistence.split(
      previous: _expense('e1', DateTime(2026, 1, 15)),
      next: _expense('e2', DateTime(2026, 3, 15)),
    );

    expect(result.id, isNotNull);
    expect(result.id, isNot('e2'));
  });

  test('creates a local identity when split throws', () async {
    firestore.throwOnSplit = true;

    final result = await persistence.split(
      previous: _expense('e1', DateTime(2026, 1, 15)),
      next: _expense('e2', DateTime(2026, 3, 15)),
    );

    expect(result.id, isNotNull);
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
