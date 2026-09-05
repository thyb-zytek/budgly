import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:budgly/src/stores/expenses.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../fixtures/builders.dart';

class OfflineFirestore extends ExpenseFirestore {
  bool offline = true;
  final server = <Expense>[];
  final local = <Expense>[];

  @override
  Future<Expense?> create(Expense expense) async {
    local.removeWhere((e) => e.id == expense.id);
    local.add(expense);
    if (!offline) {
      server.removeWhere((e) => e.id == expense.id);
      server.add(expense);
    }
    return expense;
  }

  @override
  Future<bool> update(Expense expense) async {
    local.removeWhere((e) => e.id == expense.id);
    local.add(expense);
    if (!offline) {
      server.removeWhere((e) => e.id == expense.id);
      server.add(expense);
    }
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    local.removeWhere((e) => e.id == id);
    if (!offline) server.removeWhere((e) => e.id == id);
    return true;
  }

  @override
  Future<List<Expense>> listByAccountAndPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    Source source = Source.server,
  }) async {
    final sourceData = offline ? local : server;
    return sourceData.where((e) =>
      e.accountId == accountId &&
      period.contains(e.debitDate) &&
      (categoryId == null || e.categoryId == categoryId),
    ).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const period = Period(year: 2026, month: 3);
  late OfflineFirestore firestore;
  late ExpensesService service;

  setUp(() {
    ExpensesStore.instance.clearAll();
    firestore = OfflineFirestore();
    service = ExpensesService(
      expenseFirestore: firestore,
      store: ExpensesStore.instance,
    );
  });

  tearDown(() => service.dispose());

  Expense expense({
    String id = 'e1',
    String accountId = 'a1',
    String categoryId = 'c1',
    double amount = 100,
    DateTime? date,
  }) => Fixtures.expense(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        debitDate: date ?? DateTime(2026, 3, 15),
      );

  test('offline create is immediately visible without server', () async {
    await service.createExpense(expense());

    expect(service.getExpenseById('e1')?.amount, 100);
    expect(service.cachedExpensesForPeriod('a1', period), hasLength(1));
  });

  test('offline create then update propagates to store and period cache', () async {
    final original = expense();
    await service.createExpense(original);
    await service.updateExpense(original.copyWith(amount: 250), previous: original);

    expect(service.getExpenseById('e1')?.amount, 250);
    expect(service.cachedExpensesForPeriod('a1', period)!.single.amount, 250);
  });

  test('offline update changing category keeps same identity and updates consumers', () async {
    final original = expense(categoryId: 'c1');
    await service.createExpense(original);
    await service.updateExpense(original.copyWith(categoryId: 'c2'), previous: original);

    final current = service.getExpenseById('e1')!;
    expect(current.categoryId, 'c2');
    expect(service.cachedExpensesForPeriod('a1', period)!.single.categoryId, 'c2');
  });

  test('offline update changing account removes old account projection and adds new one when loaded', () async {
    final original = expense(accountId: 'a1');
    await service.createExpense(original);
    // Prime the destination projection before moving the expense.
    await service.listExpensesForPeriod('a2', period);

    await service.updateExpense(original.copyWith(accountId: 'a2'), previous: original);

    expect(service.cachedExpensesForPeriod('a1', period), isEmpty);
    expect(service.cachedExpensesForPeriod('a2', period)!.single.accountId, 'a2');
  });

  test('offline update changing period removes old projection and updates new period', () async {
    final original = expense(date: DateTime(2026, 3, 15));
    await service.createExpense(original);
    await service.listExpensesForPeriod('a1', const Period(year: 2026, month: 4));

    final moved = original.copyWith(debitDate: DateTime(2026, 4, 10));
    await service.updateExpense(moved, previous: original);

    expect(service.cachedExpensesForPeriod('a1', period), isEmpty);
    expect(service.cachedExpensesForPeriod('a1', const Period(year: 2026, month: 4))!.single.id, 'e1');
  });

  test('offline debit mutation is immediately visible', () async {
    final original = expense();
    await service.createExpense(original);
    await service.markOccurrenceDebited(original, original.debitDate);

    expect(service.getExpenseById('e1')!.isDebited, isTrue);
  });

  test('offline delete removes the local entity after local persistence succeeds', () async {
    final original = expense();
    await service.createExpense(original);
    await service.deleteExpense('e1', 'a1');

    expect(service.getExpenseById('e1'), isNull);
    expect(service.cachedExpensesForPeriod('a1', period), isEmpty);
    expect(firestore.local, isEmpty);
  });

  test('active consumers receive every mutation without reload', () async {
    final original = expense();
    final events = <List<Expense>>[];
    void listener() => events.add(service.getExpensesForAccount('a1'));
    service.addListener(listener);
    addTearDown(() => service.removeListener(listener));

    await service.createExpense(original);
    await service.updateExpense(original.copyWith(amount: 150), previous: original);

    expect(events, isNotEmpty);
    expect(events.last.single.amount, 150);
  });
}
