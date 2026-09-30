import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_manager_provider.dart';
import 'package:budgly/src/shared/ui/widgets/banners/sync_issue_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import '../test/fixtures/builders.dart';
import '../test/helpers/offline_expense_firestore.dart';
import 'sync_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await integrationSyncQueue.clear();
    await integrationSyncManager.resetForTest();
  });

  tearDown(() async {
    await integrationSyncQueue.clear();
    await integrationSyncManager.resetForTest();
  });

  testWidgets(
    'offline mutation becomes visible in banner and retry keeps it recoverable',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncManagerProvider.overrideWithValue(integrationSyncManager),
          ],
          child: const MaterialApp(
            locale: Locale('fr'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('fr'), Locale('en')],
            home: Scaffold(body: SyncIssueBanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final queue = integrationSyncQueue;
      final manager = integrationSyncManager;
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
    },
  );
  testWidgets('offline expense state survives a stale server refresh', (
    tester,
  ) async {
    final firestore = OfflineAwareExpenseFirestore();
    final service = ExpensesService(
      expenseFirestore: firestore,
      analytics: AnalyticsService(),
    );
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

    firestore.goOnline();
    await service.listExpensesForPeriod(
      'a1',
      const Period(year: 2026, month: 3),
      forceRefresh: true,
    );

    expect(service.getExpenseById('integration-e1')?.amount, 125);
  });

  testWidgets('persistent sync queue survives a simulated app restart', (
    tester,
  ) async {
    final queue = integrationSyncQueue;
    await queue.enqueue(
      id: 'restart-expense',
      type: 'integration-restart',
      operation: 'update',
      payload: {'id': 'e1', 'amount': 250},
    );

    // A fresh queue read represents the next process after app restart.
    final restored = await integrationSyncQueue.all();
    expect(restored.single.payload['amount'], 250);

    await queue.remove('restart-expense');
    expect(await queue.all(), isEmpty);
  });

  testWidgets(
    'repeated retry keeps local mutation recoverable until server succeeds',
    (tester) async {
      final queue = integrationSyncQueue;
      var online = false;
      var calls = 0;
      await queue.enqueue(
        id: 'retry-expense',
        type: 'integration-retry',
        operation: 'update',
        payload: {'id': 'e1', 'amount': 300},
      );

      integrationSyncManager.registerHandler('integration-retry', (_) async {
        calls++;
        if (!online) throw StateError('offline');
      });

      await integrationSyncManager.flush();
      expect(await queue.hasPending(type: 'integration-retry'), isTrue);

      online = true;
      await integrationSyncManager.flush(forceRetry: true);

      expect(calls, 2);
      expect(await queue.hasPending(type: 'integration-retry'), isFalse);
    },
  );
}
