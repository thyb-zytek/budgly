import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/pages/overview/period_expenses_provider.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';
import '../../helpers.dart';

class _FakeExpensesService extends ExpensesService {
  _FakeExpensesService(this.values) : super(analytics: AnalyticsService());
  final List<Expense> values;
  bool shouldFailLoad = false;

  @override
  Future<List<Expense>> listExpensesForPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    bool forceRefresh = false,
    void Function(List<Expense>)? onRevalidated,
  }) async {
    if (shouldFailLoad) throw Exception('boom');
    return values.where((e) => e.accountId == accountId).toList();
  }
}

class _FakeCategoriesService extends CategoriesService {
  _FakeCategoriesService(this.values)
    : super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );
  final List<Category> values;

  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
    void Function(List<Category>)? onRevalidated,
  }) async => values.where((c) => c.accountId == accountId).toList();
}

void main() {
  const period = Period(year: 2026, month: 3);

  test(
    'initial load keeps category summaries when expenses and categories sessions load in sequence',
    () async {
      final category = Fixtures.category(id: 'c1', accountId: 'a1');
      final expense = Fixtures.expense(
        accountId: 'a1',
        categoryId: 'c1',
        amount: 100,
        debitDate: DateTime(2026, 3, 10),
      );
      final container = ProviderContainer(
        overrides: [
          expensesServiceProvider.overrideWithValue(
            _FakeExpensesService([expense]),
          ),
          categoriesServiceProvider.overrideWithValue(
            _FakeCategoriesService([category]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        periodExpensesProvider('a1', period).notifier,
      );
      await notifier.load();

      final state = container.read(periodExpensesProvider('a1', period));
      expect(state.isLoaded, isTrue);
      expect(state.occurrences, hasLength(1));
      expect(state.categorySummaries, hasLength(1));
      expect(state.categorySummaries.single.category.id, 'c1');
      expect(state.categorySummaries.single.total, 100);
    },
  );

  test(
    'a failing load reports the error but keeps the previously computed state',
    () async {
      final expense = Fixtures.expense(
        accountId: 'a1',
        categoryId: 'c1',
        debitDate: DateTime(2026, 3, 10),
      );
      final service = _FakeExpensesService([expense]);
      final container = ProviderContainer(
        overrides: [
          expensesServiceProvider.overrideWithValue(service),
          categoriesServiceProvider.overrideWithValue(
            _FakeCategoriesService([]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        periodExpensesProvider('a1', period).notifier,
      );
      await notifier.load();
      expect(
        container.read(periodExpensesProvider('a1', period)).occurrences,
        hasLength(1),
      );

      service.shouldFailLoad = true;
      await notifier.load();

      final state = container.read(periodExpensesProvider('a1', period));
      expect(state.status.hasError, isTrue);
      // Previously computed occurrences are still shown rather than wiped out.
      expect(state.occurrences, hasLength(1));
    },
  );

  test(
    'a change made elsewhere in ExpensesSession recomputes this provider',
    () async {
      final container = ProviderContainer(
        overrides: [
          expensesServiceProvider.overrideWithValue(_FakeExpensesService([])),
          categoriesServiceProvider.overrideWithValue(
            _FakeCategoriesService([]),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Force the provider to exist before another part of the app writes to
      // the shared session, the way Overview + CategoryExpenses would.
      container.read(periodExpensesProvider('a1', period));
      expect(
        container.read(periodExpensesProvider('a1', period)).occurrences,
        isEmpty,
      );

      final expense = Fixtures.expense(
        accountId: 'a1',
        categoryId: 'c1',
        debitDate: DateTime(2026, 3, 12),
      );
      container.read(expensesSessionProvider.notifier).updateLocal(expense);

      expect(
        container.read(periodExpensesProvider('a1', period)).occurrences,
        hasLength(1),
      );
    },
  );

  test(
    'a change made elsewhere in CategoriesSession recomputes category summaries',
    () async {
      final expense = Fixtures.expense(
        accountId: 'a1',
        categoryId: 'c1',
        amount: 100,
        debitDate: DateTime(2026, 3, 12),
      );
      final category = Fixtures.category(id: 'c1', accountId: 'a1');
      final container = ProviderContainer(
        overrides: [
          expensesServiceProvider.overrideWithValue(
            _FakeExpensesService([expense]),
          ),
          categoriesServiceProvider.overrideWithValue(
            _FakeCategoriesService([]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        periodExpensesProvider('a1', period).notifier,
      );
      await notifier.load();
      expect(
        container.read(periodExpensesProvider('a1', period)).categorySummaries,
        isEmpty,
      );

      container.read(categoriesSessionProvider.notifier).updateLocal(category);

      final summaries = container
          .read(periodExpensesProvider('a1', period))
          .categorySummaries;
      expect(summaries, hasLength(1));
      expect(summaries.single.category.id, 'c1');
      expect(summaries.single.total, 100);
    },
  );

  test('an expense outside the requested period is filtered out', () async {
    final expense = Fixtures.expense(
      accountId: 'a1',
      categoryId: 'c1',
      debitDate: DateTime(2026, 4, 1),
    );
    final container = ProviderContainer(
      overrides: [
        expensesServiceProvider.overrideWithValue(
          _FakeExpensesService([expense]),
        ),
        categoriesServiceProvider.overrideWithValue(_FakeCategoriesService([])),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      periodExpensesProvider('a1', period).notifier,
    );
    await notifier.load();

    expect(
      container.read(periodExpensesProvider('a1', period)).occurrences,
      isEmpty,
    );
  });
}
