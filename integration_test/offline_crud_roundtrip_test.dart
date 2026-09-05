import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:budgly/src/stores/expenses.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fixtures/builders.dart';
import '../test/helpers/async_test_guard.dart';

class _OfflineRoundTripFirestore extends ExpenseFirestore {
  bool online = false;
  final server = <Expense>[];

  @override
  Future<Expense?> create(Expense expense) async {
    if (!online) throw StateError('offline');
    server.removeWhere((item) => item.id == expense.id);
    server.add(expense);
    return expense;
  }

  @override
  Future<bool> update(Expense expense) async {
    if (!online) throw StateError('offline');
    server.removeWhere((item) => item.id == expense.id);
    server.add(expense);
    return true;
  }

  @override
  Future<bool> delete(String id) async {
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
    return server.where((expense) =>
        expense.accountId == accountId &&
        period.contains(expense.debitDate) &&
        (categoryId == null || expense.categoryId == categoryId)).toList();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _OfflineRoundTripFirestore firestore;
  late ExpensesService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    ExpensesStore.instance.clearAll();
    firestore = _OfflineRoundTripFirestore();
    service = ExpensesService(expenseFirestore: firestore, store: ExpensesStore.instance);
  });

  tearDown(() async {
    service.dispose();
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    ExpensesStore.instance.clearAll();
  });

  testWidgets('offline create is visible immediately and round-trips after reconnect', (_) async {
    final expense = Fixtures.expense(
      id: 'integration-e1',
      accountId: 'a1',
      categoryId: 'c1',
      amount: 125,
    );

    await service.createExpense(expense);
    await Future<void>.delayed(Duration.zero);

    expect(service.getExpenseById('integration-e1')?.amount, 125);
    expect(await SyncQueue.instance.hasPending(type: 'expenses', entityId: 'integration-e1'), isTrue);

    firestore.online = true;
    await guardedAsync(SyncManager.instance.flush(forceRetry: true), description: 'expense sync flush');

    expect(await SyncQueue.instance.all(), isEmpty);
    expect(firestore.server.single.amount, 125);
  });

  testWidgets('offline update and delete survive until reconnect', (_) async {
    final expense = Fixtures.expense(
      id: 'integration-e2',
      accountId: 'a1',
      categoryId: 'c1',
      amount: 50,
    );
    firestore.online = true;
    await service.createExpense(expense);
    await Future<void>.delayed(Duration.zero);

    firestore.online = false;
    await service.updateExpense(expense.copyWith(amount: 90), previous: expense);
    await Future<void>.delayed(Duration.zero);
    expect(service.getExpenseById('integration-e2')?.amount, 90);

    await service.deleteExpense('integration-e2', 'a1');
    await Future<void>.delayed(Duration.zero);
    expect(service.getExpenseById('integration-e2'), isNull);

    firestore.online = true;
    await guardedAsync(SyncManager.instance.flush(forceRetry: true), description: 'expense sync flush');

    expect(await SyncQueue.instance.all(), isEmpty);
    expect(firestore.server, isEmpty);
  });
}
