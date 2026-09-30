// RL-01 §3.2 end-to-end: the Overview's data pipeline (Accounts ->
// AccountSelection, Expenses -> PeriodExpenses) must render the local cache
// immediately and then rebuild once a background server revalidation
// confirms/changes the data — not stay frozen on the first cached snapshot.
// This is the integration-level regression test for the "Overview shows
// stale/empty content and never rebuilds" bug fixed in this workstream.
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/pages/overview/account_selection_provider.dart';
import 'package:budgly/src/pages/overview/period_expenses_provider.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SyncManager _syncManager() =>
    SyncManager(queue: SyncQueue(), analytics: AnalyticsService());

/// Returns the seeded accounts immediately (no revalidation needed for this
/// scenario: only the expenses side is exercised for cache-then-revalidate).
class _FixedAccountsService extends AccountsService {
  _FixedAccountsService(this.values)
    : super(
        analytics: AnalyticsService(),
        syncManager: _syncManager(),
        syncQueue: SyncQueue(),
      );

  final List<Account> values;

  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async => values;
}

class _EmptyCategoriesService extends CategoriesService {
  _EmptyCategoriesService()
    : super(
        analytics: AnalyticsService(),
        syncManager: _syncManager(),
        syncQueue: SyncQueue(),
      );

  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
    void Function(List<Category>)? onRevalidated,
  }) async => const [];
}

/// Simulates exactly what `ExpensesService.listExpensesForPeriod` does on a
/// cache-hit: return the cached expenses immediately, and separately deliver
/// a "server-confirmed" list through [onRevalidated] whenever the test calls
/// [completeBackgroundRevalidation] — the same shape as the real background
/// Firestore revalidation, just under the test's manual control instead of a
/// real network delay.
class _ScriptedExpensesService extends ExpensesService {
  _ScriptedExpensesService(this.cached, this.serverConfirmed)
    : super(analytics: AnalyticsService());

  final List<Expense> cached;
  final List<Expense> serverConfirmed;
  void Function(List<Expense>)? _pendingRevalidation;

  @override
  Future<List<Expense>> listExpensesForPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    bool forceRefresh = false,
    void Function(List<Expense>)? onRevalidated,
  }) async {
    _pendingRevalidation = onRevalidated;
    return cached;
  }

  void completeBackgroundRevalidation() =>
      _pendingRevalidation?.call(serverConfirmed);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Overview renders the cache immediately, then rebuilds once the server '
    'confirms fresher data (RL-01 §3.2)',
    (_) async {
      const account = Account(id: 'a1', name: 'Courant');
      const period = Period(year: 2026, month: 9);
      final cachedExpense = Expense(
        id: 'e1',
        accountId: 'a1',
        categoryId: 'c1',
        name: 'Loyer',
        amount: 800,
        debitDate: DateTime(2026, 9, 3),
      );
      final serverExpense = Expense(
        id: 'e2',
        accountId: 'a1',
        categoryId: 'c1',
        name: 'Courses',
        amount: 120,
        debitDate: DateTime(2026, 9, 10),
      );
      final expensesService = _ScriptedExpensesService(
        [cachedExpense],
        [cachedExpense, serverExpense],
      );

      final container = ProviderContainer(
        overrides: [
          accountsServiceProvider.overrideWithValue(
            _FixedAccountsService([account]),
          ),
          categoriesServiceProvider.overrideWithValue(
            _EmptyCategoriesService(),
          ),
          expensesServiceProvider.overrideWithValue(expensesService),
        ],
      );
      addTearDown(container.dispose);

      // Step 1: AccountSelection loads and picks the only account, exactly
      // as Overview.loadInitialData does.
      await container.read(accountSelectionProvider.notifier).load();
      final accountId = container
          .read(accountSelectionProvider)
          .selectedAccount!
          .id!;
      expect(accountId, 'a1');

      // Step 2: PeriodExpenses does a cache-first load for that account.
      final periodNotifier = container.read(
        periodExpensesProvider(accountId, period).notifier,
      );
      await periodNotifier.load();
      expect(
        container
            .read(periodExpensesProvider(accountId, period))
            .expenses
            .map((e) => e.id),
        ['e1'],
        reason: 'the cache-first snapshot must render immediately',
      );

      // Step 3: the server confirms a different (fresher) list in the
      // background, exactly as ExpensesService's background revalidation
      // does on a real cache-hit.
      expensesService.completeBackgroundRevalidation();

      expect(
        container
            .read(periodExpensesProvider(accountId, period))
            .expenses
            .map((e) => e.id),
        containsAll(['e1', 'e2']),
        reason:
            'Overview must rebuild from the server-confirmed data once '
            'the background revalidation completes, not stay frozen on the '
            'first cached snapshot',
      );
    },
  );
}
