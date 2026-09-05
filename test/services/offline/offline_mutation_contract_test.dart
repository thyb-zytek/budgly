import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/stores/expenses.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';
import '../../helpers/async_test_guard.dart';

class _ControllableExpenseFirestore extends ExpenseFirestore {
  bool online = true;
  final List<Expense> server = [];
  final List<String> calls = [];
  bool splitOnline = true;

  @override
  Future<Expense?> create(Expense expense) async {
    calls.add('create:${expense.id}');
    if (!online) throw StateError('offline');
    server.removeWhere((item) => item.id == expense.id);
    server.add(expense);
    return expense;
  }

  @override
  Future<bool> update(Expense expense) async {
    calls.add('update:${expense.id}');
    if (!online) throw StateError('offline');
    server.removeWhere((item) => item.id == expense.id);
    server.add(expense);
    return true;
  }

  @override
  Future<Expense?> splitRecurringExpense({
    required Expense previous,
    required Expense next,
  }) async {
    calls.add('split:${previous.id}');
    if (!splitOnline) throw StateError('offline');
    server.removeWhere((item) => item.id == previous.id || item.id == next.id);
    server.add(previous);
    final resolved = next.id == null ? next.copyWith(id: 'server-next') : next;
    server.add(resolved);
    return resolved;
  }

  @override
  Future<bool> delete(String id) async {
    calls.add('delete:$id');
    if (!online) throw StateError('offline');
    server.removeWhere((item) => item.id == id);
    return true;
  }

  @override
  Future<List<Expense>> listByAccountAndPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    Source source = Source.server,
  }) async {
    if (!online && source == Source.server) throw StateError('offline');
    return server.where((expense) {
      return expense.accountId == accountId &&
          period.contains(expense.debitDate) &&
          (categoryId == null || expense.categoryId == categoryId);
    }).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const period = Period(year: 2026, month: 3);

  late _ControllableExpenseFirestore firestore;
  late ExpensesService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    ExpensesStore.instance.clearAll();
    firestore = _ControllableExpenseFirestore();
    service = ExpensesService(
      expenseFirestore: firestore,
      store: ExpensesStore.instance,
    );
  });

  tearDown(() async {
    service.dispose();
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    ExpensesStore.instance.clearAll();
  });

  Expense makeExpense({double amount = 100}) => Fixtures.expense(
        id: 'e1',
        accountId: 'a1',
        categoryId: 'c1',
        amount: amount,
        debitDate: DateTime(2026, 3, 15),
      );

  test('offline create remains local and becomes a queued server mutation', () async {
    firestore.online = false;
    final expense = makeExpense();

    await service.createExpense(expense);
    await Future<void>.delayed(Duration.zero);

    expect(service.getExpenseById('e1')?.amount, 100);
    final pending = await SyncQueue.instance.forType('expenses');
    expect(pending, hasLength(1));
    expect(pending.single.operation, 'create');
    expect(pending.single.payload['amount'], 100);
  });

  test('offline update keeps the newest local value and retries it after reconnect', () async {
    final original = makeExpense();
    firestore.server.add(original);
    await service.createExpense(original);
    await Future<void>.delayed(Duration.zero);

    firestore.online = false;
    await service.updateExpense(original.copyWith(amount: 250), previous: original);
    await Future<void>.delayed(Duration.zero);

    expect(service.getExpenseById('e1')?.amount, 250);
    expect((await SyncQueue.instance.forType('expenses')).single.payload['amount'], 250);

    firestore.online = true;
    await guardedAsync(SyncManager.instance.flush(forceRetry: true), description: 'expense sync flush');

    expect(await SyncQueue.instance.forType('expenses'), isEmpty);
    expect(firestore.server.single.amount, 250);
  });

  test('offline delete removes the local entity immediately and retries deletion after reconnect', () async {
    final expense = makeExpense();
    firestore.server.add(expense);
    await service.createExpense(expense);
    await Future<void>.delayed(Duration.zero);

    firestore.online = false;
    expect(await service.deleteExpense('e1', 'a1'), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(service.getExpenseById('e1'), isNull);
    expect((await SyncQueue.instance.forType('expenses')).single.operation, 'delete');

    firestore.online = true;
    await guardedAsync(SyncManager.instance.flush(forceRetry: true), description: 'expense sync flush');

    expect(await SyncQueue.instance.forType('expenses'), isEmpty);
    expect(firestore.server, isEmpty);
  });

  test('a stale server snapshot cannot overwrite a newer pending local update', () async {
    final original = makeExpense(amount: 100);
    firestore.server.add(original);
    await service.listExpensesForPeriod('a1', period, forceRefresh: true);

    firestore.online = false;
    final updated = original.copyWith(amount: 300);
    await service.updateExpense(updated, previous: original);
    await Future<void>.delayed(Duration.zero);

    firestore.online = true;
    firestore.server
      ..clear()
      ..add(original);

    await service.listExpensesForPeriod('a1', period, forceRefresh: true);

    expect(service.cachedExpensesForPeriod('a1', period)!.single.amount, 300);
    expect(
      await SyncQueue.instance.hasPending(type: 'expenses', entityId: 'e1'),
      isTrue,
    );

    firestore.server
      ..clear()
      ..add(updated);
    await guardedAsync(
      SyncManager.instance.flush(forceRetry: true),
      description: 'expense sync flush',
    );

    expect(
      await SyncQueue.instance.hasPending(type: 'expenses', entityId: 'e1'),
      isFalse,
    );
  });

  test('offline recurring edit queues the old-series update before the new-series create', () async {
    final original = Fixtures.expense(
      id: 'r1',
      accountId: 'a1',
      categoryId: 'c1',
      amount: 100,
      debitDate: DateTime(2026, 1, 15),
      recurrence: RecurrenceType.monthly,
      recurrenceAnchorDay: 15,
    );
    firestore.splitOnline = false;
    firestore.online = false;

    final updated = original.copyWith(amount: 150);
    final result = await service.updateRecurringExpenseFromOccurrence(
      original: original,
      updated: updated,
      effectiveDate: DateTime(2026, 3, 15),
    );
    await Future<void>.delayed(Duration.zero);

    expect(result.amount, 150);
    final pending = await SyncQueue.instance.forType('expenses');
    expect(pending.map((operation) => operation.operation), ['update', 'create']);
    expect(pending.first.payload['id'], 'r1');
    expect(pending.last.payload['amount'], 150);
  });

  test('rapid local mutations coalesce to the last payload', () async {
    firestore.online = false;
    final original = makeExpense();
    await service.createExpense(original);
    await Future<void>.delayed(Duration.zero);

    await service.updateExpense(original.copyWith(amount: 200), previous: original);
    await service.updateExpense(original.copyWith(amount: 300), previous: original.copyWith(amount: 200));
    await service.updateExpense(original.copyWith(amount: 400), previous: original.copyWith(amount: 300));
    await Future<void>.delayed(Duration.zero);

    final pending = await SyncQueue.instance.forType('expenses');
    expect(pending, hasLength(1));
    expect(pending.single.operation, 'create');
    expect(pending.single.payload['amount'], 400);
  });
}
