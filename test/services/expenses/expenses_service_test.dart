import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates a server that answered a query *before* a locally-created
/// expense became visible on the server (pending write / slow network).
class PendingWriteExpenseFirestore extends ExpenseFirestore {
  final List<Expense> serverExpenses = [];
  bool acknowledgeCreate = false;

  @override
  Future<Expense?> create(Expense expense) async => acknowledgeCreate ? expense : null;

  @override
  Future<List<Expense>> listByAccountAndPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    Source source = Source.server,
  }) async {
    return serverExpenses
        .where(
          (expense) =>
              expense.accountId == accountId &&
              period.contains(expense.debitDate),
        )
        .toList();
  }
}

void main() {
  const period = Period(year: 2026, month: 8);
  late PendingWriteExpenseFirestore firestore;
  late ExpensesService service;

  setUp(() {
    firestore = PendingWriteExpenseFirestore();
    service = ExpensesService(expenseFirestore: firestore);
    service.invalidateCache();
  });

  tearDown(() {
    service.dispose();
  });

  Expense expense({String id = 'e1', String accountId = 'a1'}) => Expense(
    id: id,
    accountId: accountId,
    categoryId: 'c1',
    name: 'Café',
    amount: 4.5,
    debitDate: DateTime(2026, 8, 15),
  );

  test('created expense is visible from the period cache immediately', () async {
    await service.createExpense(expense());

    final listed = await service.listExpensesForPeriod('a1', period);

    expect(listed.map((e) => e.id), ['e1']);
  });

  test('a stale server refresh does not drop a just-created first expense',
      () async {
    // The account currently has nothing on the server.
    expect(await service.listExpensesForPeriod('a1', period), isEmpty);

    final created = await service.createExpense(expense());
    expect(created.id, 'e1');

    // The server has not acknowledged the write yet: a forced refresh must
    // keep the optimistic expense instead of flushing the cache to empty.
    final listed = await service.listExpensesForPeriod(
      'a1',
      period,
      forceRefresh: true,
    );

    expect(listed.map((e) => e.id), ['e1']);
  });

  test('optimistic shield is released once the server acknowledges the expense',
      () async {
    firestore.acknowledgeCreate = true;

    await service.createExpense(expense());
    firestore.serverExpenses.add(expense());

    final listed = await service.listExpensesForPeriod(
      'a1',
      period,
      forceRefresh: true,
    );

    expect(listed.map((e) => e.id), ['e1']);

    // Now that the id is acknowledged, a server-side deletion propagates.
    firestore.serverExpenses.clear();
    final afterRemoteDelete = await service.listExpensesForPeriod(
      'a1',
      period,
      forceRefresh: true,
    );
    expect(afterRemoteDelete, isEmpty);
  });

  test('server data is restored for the period cache on refresh', () async {
    firestore.serverExpenses.addAll([
      expense(),
      expense(id: 'e2'),
    ]);

    final listed = await service.listExpensesForPeriod(
      'a1',
      period,
      forceRefresh: true,
    );

    expect(listed.map((e) => e.id).toSet(), {'e1', 'e2'});
  });

  test(
    'a stale server refresh does not drop a previously-created expense '
    'when a second expense is created',
    () async {
      // Simulate the first expense being persisted (server acknowledges it
      // locally) and the optimistic shield being released.
      firestore.acknowledgeCreate = true;
      await service.createExpense(expense());

      // The server has not yet synced the expense to its query results.
      // A background refresh triggered by the second creation must not
      // drop the first expense.
      final e2 = Expense(
        id: 'e2',
        accountId: 'a1',
        categoryId: 'c2',
        name: 'Transport',
        amount: 12.0,
        debitDate: DateTime(2026, 8, 15),
      );
      await service.createExpense(e2);

      // Simulate a background refresh that returns stale server data.
      final listed = await service.listExpensesForPeriod(
        'a1',
        period,
        forceRefresh: true,
      );

      expect(
        listed.map((e) => e.id).toSet(),
        containsAll(['e1', 'e2']),
      );
    },
  );
}