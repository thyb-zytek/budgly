import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:budgly/src/stores/expenses.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../fixtures/builders.dart';

class ReconnectFirestore extends ExpenseFirestore {
  bool offline = true;
  final server = <Expense>[];
  int serverReads = 0;

  @override
  Future<Expense?> create(Expense expense) async {
    if (offline) throw StateError('offline');
    server.removeWhere((e) => e.id == expense.id);
    server.add(expense);
    return expense;
  }

  @override
  Future<bool> update(Expense expense) async {
    if (offline) throw StateError('offline');
    server.removeWhere((e) => e.id == expense.id);
    server.add(expense);
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    if (offline) throw StateError('offline');
    server.removeWhere((e) => e.id == id);
    return true;
  }

  @override
  Future<List<Expense>> listByAccountAndPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    Source source = Source.server,
  }) async {
    if (source == Source.server) {
      serverReads++;
      if (offline) throw StateError('offline');
    }
    return server.where((e) {
      return e.accountId == accountId &&
          period.contains(e.debitDate) &&
          (categoryId == null || e.categoryId == categoryId);
    }).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const period = Period(year: 2026, month: 3);
  late ReconnectFirestore firestore;
  late ExpensesService service;

  setUp(() {
    ExpensesStore.instance.clearAll();
    firestore = ReconnectFirestore();
    service = ExpensesService(
      expenseFirestore: firestore,
      store: ExpensesStore.instance,
    );
  });

  tearDown(() => service.dispose());

  test('offline mutation remains visible after reconnect refresh', () async {
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 100,
    );

    await service.createExpense(expense);
    await Future<void>.delayed(Duration.zero);

    expect(service.getExpenseById('e1')?.amount, 100);

    firestore.offline = false;
    firestore.server.add(expense.copyWith(amount: 100));

    await service.listExpensesForPeriod('a1', period, forceRefresh: true);

    expect(service.getExpenseById('e1')?.amount, 100);
    expect(service.cachedExpensesForPeriod('a1', period), hasLength(1));
  });

  test('server stale snapshot does not erase a locally-created expense', () async {
    final expense = Fixtures.expense(
      id: 'local-e1', accountId: 'a1', categoryId: 'c1', amount: 125,
    );

    await service.createExpense(expense);
    firestore.offline = false;

    // The server intentionally has no copy yet: simulate a stale snapshot.
    await service.listExpensesForPeriod('a1', period, forceRefresh: true);

    expect(service.cachedExpensesForPeriod('a1', period), hasLength(1));
    expect(service.cachedExpensesForPeriod('a1', period)!.single.id, 'local-e1');
  });

  test('rapid consecutive local mutations leave the last state visible', () async {
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 10,
    );
    await service.createExpense(expense);

    await service.updateExpense(expense.copyWith(amount: 20), previous: expense);
    await service.updateExpense(expense.copyWith(amount: 30), previous: expense.copyWith(amount: 20));
    await service.updateExpense(expense.copyWith(amount: 40), previous: expense.copyWith(amount: 30));

    expect(service.getExpenseById('e1')?.amount, 40);
    expect(service.cachedExpensesForPeriod('a1', period)?.single.amount, 40);
  });
}
