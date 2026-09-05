import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/shared/ui/widgets/banners/sync_issue_banner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:budgly/src/stores/expenses.dart';
import '../test/fixtures/builders.dart';

class _IntegrationExpenseFirestore extends ExpenseFirestore {
  bool offline = true;
  final server = <Expense>[];

  @override
  Future<Expense?> create(Expense expense) async {
    if (offline) throw StateError('offline');
    server.removeWhere((item) => item.id == expense.id);
    server.add(expense);
    return expense;
  }

  @override
  Future<bool> update(Expense expense) async {
    if (offline) throw StateError('offline');
    server.removeWhere((item) => item.id == expense.id);
    server.add(expense);
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    if (offline) throw StateError('offline');
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
    if (offline && source == Source.server) throw StateError('offline');
    return server.where((expense) =>
        expense.accountId == accountId &&
        period.contains(expense.debitDate) &&
        (categoryId == null || expense.categoryId == categoryId)).toList();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncQueue.instance.clear();
    await SyncManager.instance.resetForTest();
  });

  tearDown(() async {
    await SyncQueue.instance.clear();
    await SyncManager.instance.resetForTest();
  });

  testWidgets('offline mutation becomes visible in banner and retry keeps it recoverable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('fr'), Locale('en')],
        home: Scaffold(
          body: SyncIssueBanner(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final queue = SyncQueue.instance;
    final manager = SyncManager.instance;
    await queue.enqueue(
      id: 'integration-offline-expense',
      type: 'integration-offline',
      operation: 'update',
      payload: {'id': 'e1'},
    );
    for (var i = 0; i < SyncManager.stuckAfterAttempts; i++) {
      await queue.markFailed('integration-offline-expense');
    }

    manager.registerHandler('integration-offline', (_) async {
      throw StateError('offline');
    });
    await manager.flush();
    await tester.pump();

    expect(find.text('Réessayer'), findsOneWidget);
    expect(manager.hasStuckOperations, isTrue);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    // A retry failure must not discard the pending mutation. The user can
    // retry again when connectivity is restored.
    expect(await queue.hasPending(type: 'integration-offline'), isTrue);
    expect(find.text('Réessayer'), findsOneWidget);
  });
  testWidgets('offline expense state survives a stale server refresh', (tester) async {
    final firestore = _IntegrationExpenseFirestore();
    final service = ExpensesService(
      expenseFirestore: firestore,
      store: ExpensesStore.instance,
    );
    addTearDown(service.dispose);
    service.invalidateCache();

    final expense = Fixtures.expense(
      id: 'integration-e1',
      accountId: 'a1',
      categoryId: 'c1',
      amount: 125,
      debitDate: DateTime(2026, 3, 15),
    );

    await service.createExpense(expense);
    expect(service.getExpenseById('integration-e1')?.amount, 125);

    firestore.offline = false;
    await service.listExpensesForPeriod(
      'a1',
      const Period(year: 2026, month: 3),
      forceRefresh: true,
    );

    expect(service.getExpenseById('integration-e1')?.amount, 125);
  });

  testWidgets('persistent sync queue survives a simulated app restart', (tester) async {
    final queue = SyncQueue.instance;
    await queue.enqueue(
      id: 'restart-expense',
      type: 'expenses',
      operation: 'update',
      payload: {'id': 'e1', 'amount': 250},
    );

    // A fresh queue read represents the next process after app restart.
    final restored = await SyncQueue.instance.all();
    expect(restored.single.payload['amount'], 250);

    await queue.remove('restart-expense');
    expect(await queue.all(), isEmpty);
  });

  testWidgets('repeated retry keeps local mutation recoverable until server succeeds', (tester) async {
    final queue = SyncQueue.instance;
    var online = false;
    var calls = 0;
    await queue.enqueue(
      id: 'retry-expense',
      type: 'integration-retry',
      operation: 'update',
      payload: {'id': 'e1', 'amount': 300},
    );

    SyncManager.instance.registerHandler('integration-retry', (_) async {
      calls++;
      if (!online) throw StateError('offline');
    });

    await SyncManager.instance.flush();
    expect(await queue.hasPending(type: 'integration-retry'), isTrue);

    online = true;
    await SyncManager.instance.flush(forceRetry: true);

    expect(calls, 2);
    expect(await queue.hasPending(type: 'integration-retry'), isFalse);
  });

}
