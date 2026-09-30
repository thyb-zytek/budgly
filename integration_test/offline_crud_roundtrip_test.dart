import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fixtures/builders.dart';
import '../test/helpers/offline_expense_firestore.dart';
import 'sync_test_harness.dart';

/// Expense writes rely on Firestore's own offline queue (single durable queue).
/// The fake reproduces the SDK behaviour: a write is applied locally at once
/// and its Future only completes once the server acknowledges it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late OfflineAwareExpenseFirestore firestore;
  late ExpensesService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await integrationSyncManager.resetForTest();
    await integrationSyncQueue.clear();
    firestore = OfflineAwareExpenseFirestore();
    service = ExpensesService(
      expenseFirestore: firestore,
      analytics: AnalyticsService(),
    );
  });

  tearDown(() async {
    await integrationSyncManager.resetForTest();
    await integrationSyncQueue.clear();
    service.invalidateCache();
  });

  testWidgets(
    'offline create is visible immediately and round-trips after reconnect',
    (_) async {
      final expense = Fixtures.expense(
        id: 'integration-e1',
        accountId: 'a1',
        categoryId: 'c1',
        amount: 125,
      );

      await service.createExpense(expense);

      expect(service.getExpenseById('integration-e1')?.amount, 125);
      expect(firestore.pendingWriteCount, 1);
      expect(await integrationSyncQueue.all(), isEmpty);

      firestore.goOnline();
      await Future<void>.delayed(Duration.zero);

      expect(firestore.server.single.amount, 125);
    },
  );

  testWidgets(
    'offline update and delete do not block and survive until reconnect',
    (_) async {
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
      await service.updateExpense(
        expense.copyWith(amount: 90),
        previous: expense,
      );
      expect(service.getExpenseById('integration-e2')?.amount, 90);

      await service
          .deleteExpense('integration-e2', 'a1')
          .timeout(const Duration(seconds: 2));
      expect(service.getExpenseById('integration-e2'), isNull);

      firestore.goOnline();
      await Future<void>.delayed(Duration.zero);

      expect(await integrationSyncQueue.all(), isEmpty);
      expect(firestore.server, isEmpty);
    },
  );
}
