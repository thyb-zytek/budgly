import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/pages/settings/categories/categories_settings_provider.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/builders.dart';
import '../../../helpers.dart';

/// Regression coverage: deleting a category deletes its expenses on the
/// backend (`deleteByCategoryId`), but that call never touched
/// ExpensesSession, so the deleted expenses kept showing up on Overview
/// until something else happened to reload the account.
class _FakeCategoriesService extends CategoriesService {
  _FakeCategoriesService()
    : super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );
  @override
  Future<bool> deleteCategory(String categoryId, {String? accountId}) async =>
      true;

  @override
  Future<List<CategoryIcon>> loadAvailableIcons() async => const [];
}

class _FakeExpensesServiceForCategories extends ExpensesService {
  _FakeExpensesServiceForCategories(this.values)
    : super(analytics: AnalyticsService());
  final List<Expense> values;
  int deleteByCategoryCalls = 0;

  @override
  Future<void> deleteByCategoryId(String categoryId) async {
    deleteByCategoryCalls++;
  }

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async =>
      values.where((expense) => expense.accountId == accountId).toList();
}

void main() {
  test('removeCategory clears the account from ExpensesSession', () async {
    final expense = Expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      name: 'Loyer',
      amount: 850,
      debitDate: DateTime(2026, 3, 5),
    );
    final expensesService = _FakeExpensesServiceForCategories([expense]);
    final container = ProviderContainer(
      overrides: [
        categoriesServiceProvider.overrideWithValue(_FakeCategoriesService()),
        expensesServiceProvider.overrideWithValue(expensesService),
      ],
    );
    addTearDown(container.dispose);

    // Seed the shared session the way Overview/CategoryExpenses would.
    await container.read(expensesSessionProvider.notifier).loadAccount('a1');
    expect(
      container.read(expensesSessionProvider).loadedAccounts,
      contains('a1'),
    );
    expect(
      container.read(expensesSessionProvider.notifier).getExpenseById('e1'),
      isNotNull,
    );

    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    await container
        .read(categoriesSettingsProvider.notifier)
        .removeCategory(category);

    expect(expensesService.deleteByCategoryCalls, 1);
    // The account was invalidated: no stale expense lingers in the shared
    // session (it will be refetched next time the account is loaded).
    expect(
      container.read(expensesSessionProvider).loadedAccounts,
      isNot(contains('a1')),
    );
    expect(
      container.read(expensesSessionProvider.notifier).getExpenseById('e1'),
      isNull,
    );
    expect(container.read(categoriesSettingsProvider).status.hasError, isFalse);
  });
}
