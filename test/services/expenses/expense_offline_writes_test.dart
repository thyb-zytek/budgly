import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';
import '../../helpers.dart';

/// Regression tests for the expense write path against a fake that behaves like
/// the real Firestore SDK offline: local write applied at once, write Future
/// pending until the server acknowledges it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const period = Period(year: 2026, month: 3);
  late OfflineAwareExpenseFirestore firestore;
  late ExpensesService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
    firestore = OfflineAwareExpenseFirestore();
    service = ExpensesService(
      expenseFirestore: firestore,
      analytics: AnalyticsService(),
    );
  });

  tearDown(() async {
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
  });

  final expense = Fixtures.expense(
    id: 'e1',
    accountId: 'a1',
    categoryId: 'c1',
    amount: 125,
    debitDate: DateTime(2026, 3, 15),
  );

  test(
    'offline create returns immediately and is delivered by Firestore itself',
    () async {
      final created = await service
          .createExpense(expense)
          .timeout(const Duration(seconds: 2));

      expect(created.id, 'e1');
      expect(service.getExpenseById('e1')?.amount, 125);
      expect(firestore.pendingWriteCount, 1);
      // Single durable queue: nothing is duplicated in the application queue.
      expect(await testSyncQueue.all(), isEmpty);

      firestore.goOnline();
      await Future<void>.delayed(Duration.zero);

      expect(firestore.server.single.amount, 125);
      expect(await testSyncQueue.all(), isEmpty);
    },
  );

  test(
    'offline delete does not block the caller until the network returns',
    () async {
      firestore.online = true;
      await service.createExpense(expense);
      await Future<void>.delayed(Duration.zero);
      firestore.online = false;

      // Before the fix this awaited the (never-completing) Firestore delete.
      final deleted = await service
          .deleteExpense('e1', 'a1')
          .timeout(const Duration(seconds: 2));

      expect(deleted, isTrue);
      expect(service.getExpenseById('e1'), isNull);
      expect(firestore.pendingWriteCount, 1);

      firestore.goOnline();
      await Future<void>.delayed(Duration.zero);
      expect(firestore.server, isEmpty);
      expect(await testSyncQueue.all(), isEmpty);
    },
  );

  test(
    'offline updates converge to the last edit without a stale replay',
    () async {
      firestore.online = true;
      await service.createExpense(expense);
      await Future<void>.delayed(Duration.zero);
      firestore.online = false;

      await service.updateExpense(
        expense.copyWith(amount: 200),
        previous: expense,
      );
      await service.updateExpense(
        expense.copyWith(amount: 300),
        previous: expense.copyWith(amount: 200),
      );
      expect(service.getExpenseById('e1')?.amount, 300);

      firestore.goOnline();
      await Future<void>.delayed(Duration.zero);

      // Firestore replays its own queue in order; no second queue can overwrite
      // the newest value with an older one.
      expect(firestore.server.single.amount, 300);
      expect(await testSyncQueue.all(), isEmpty);
    },
  );

  test('a stale server refresh does not drop an offline creation', () async {
    await service.createExpense(expense);

    firestore.online = true;
    await service.listExpensesForPeriod('a1', period, forceRefresh: true);

    expect(service.getExpenseById('e1')?.amount, 125);
  });

  test(
    'an empty offline period is answered from the cache without waiting for the server',
    () async {
      final result = await service
          .listExpensesForPeriod('a1', period)
          .timeout(const Duration(seconds: 2));

      expect(result, isEmpty);
    },
  );

  test(
    'a write rejected by the server is reported and its optimistic state dropped',
    () async {
      final rejected = <String>[];
      final subscription = service.rejectedWrites.listen(rejected.add);
      addTearDown(subscription.cancel);

      firestore.online = true;
      await service.createExpense(expense);
      await Future<void>.delayed(Duration.zero);
      firestore.rejectWrites = true;

      await service.updateExpense(
        expense.copyWith(amount: 999),
        previous: expense,
      );
      await Future<void>.delayed(Duration.zero);

      expect(rejected, ['a1']);
      expect(firestore.server.single.amount, 125);
    },
  );

  test('operations queued by older builds are still drained', () async {
    firestore.online = true;
    service.registerSyncHandler(testSyncManager);
    await testSyncQueue.enqueue(
      id: 'expense:create:e1',
      type: 'expenses',
      operation: 'create',
      payload: expense.toJson(),
    );

    await testSyncManager.flush(forceRetry: true);

    expect(firestore.server.single.id, 'e1');
    expect(await testSyncQueue.all(), isEmpty);
  });
}
