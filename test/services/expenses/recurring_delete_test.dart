import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeExpenseFirestore extends ExpenseFirestore {
  Expense? lastCreatedNext;
  Expense? lastUpdatedPrevious;
  bool deleteCalled = false;
  String? deletedId;

  @override
  Future<bool> delete(String expenseId) async {
    deleteCalled = true;
    deletedId = expenseId;
    return true;
  }

  @override
  Future<bool> update(Expense expense) async => true;

  @override
  Future<Expense?> splitRecurringExpense({
    required Expense previous,
    required Expense next,
  }) async {
    lastUpdatedPrevious = previous;
    lastCreatedNext = next;
    return next.copyWith(id: 'new-id');
  }
}

void main() {
  late FakeExpenseFirestore firestore;
  late ExpensesService service;

  setUp(() {
    firestore = FakeExpenseFirestore();
    service = ExpensesService(expenseFirestore: firestore);
    service.invalidateCache();
  });

  tearDown(() => service.dispose());

  Expense monthly(String id, DateTime debitDate, {DateTime? endDate}) => Expense(
        id: id,
        accountId: 'a1',
        categoryId: 'c1',
        name: 'Rent',
        amount: 100,
        debitDate: debitDate,
        endDate: endDate,
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: debitDate.day,
        debitedOccurrences: const [],
      );

  test('deleteFutureOccurrences from first deletes entire expense', () async {
    final expense = monthly('e1', DateTime(2026, 1, 15));
    service.invalidateCache();
    // Seed store via create then delete future
    // Directly test service method – it will call deleteExpense
    final result = await service.deleteFutureOccurrences(
      expense: expense,
      occurrenceDate: DateTime(2026, 1, 15),
    );
    expect(result, isTrue);
    expect(firestore.deleteCalled, isTrue);
    expect(firestore.deletedId, 'e1');
  });

  test('deleteFutureOccurrences truncates series', () async {
    final expense = monthly('e1', DateTime(2026, 1, 15));
    final occurrence = DateTime(2026, 3, 15);
    final result = await service.deleteFutureOccurrences(
      expense: expense,
      occurrenceDate: occurrence,
    );
    expect(result, isTrue);
    // Should have updated, not deleted
    expect(firestore.deleteCalled, isFalse);
  });

  test('deleteSingleOccurrence first shifts debitDate', () async {
    final expense = monthly('e1', DateTime(2026, 1, 15));
    final result = await service.deleteSingleOccurrence(
      expense: expense,
      occurrenceDate: DateTime(2026, 1, 15),
    );
    expect(result, isTrue);
    expect(firestore.deleteCalled, isFalse);
  });

  test('deleteSingleOccurrence middle creates split', () async {
    final expense = monthly('e1', DateTime(2026, 1, 15));
    final result = await service.deleteSingleOccurrence(
      expense: expense,
      occurrenceDate: DateTime(2026, 2, 15),
    );
    expect(result, isTrue);
    expect(firestore.lastCreatedNext, isNotNull);
    expect(firestore.lastUpdatedPrevious, isNotNull);
    expect(firestore.lastUpdatedPrevious!.endDate, DateTime(2026, 2, 14));
    expect(firestore.lastCreatedNext!.debitDate, DateTime(2026, 3, 15));
  });

  test('deleteSingleOccurrence non-recurring deletes', () async {
    final expense = Expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      name: 'Coffee',
      amount: 5,
      debitDate: DateTime(2026, 1, 15),
    );
    final result = await service.deleteSingleOccurrence(
      expense: expense,
      occurrenceDate: DateTime(2026, 1, 15),
    );
    expect(result, isTrue);
    expect(firestore.deleteCalled, isTrue);
  });
}
