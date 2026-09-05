import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/pages/settings/accounts/view_model.dart';
import 'package:budgly/src/pages/settings/categories/tab.dart';
import 'package:budgly/src/pages/settings/categories/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/builders.dart';
import '../../../helpers/pump_app.dart';

class _FakeAccountsService extends AccountsService {
  List<Account> values = [];

  @override
  List<Account> get accounts => values;

  @override
  bool get hasLoaded => true;

  @override
  Future<void> loadAccounts({bool forceRefresh = false}) async {}
}

class _FakeCategoriesService extends CategoriesService {
  final Map<String, List<Category>> byAccount;
  _FakeCategoriesService(this.byAccount);

  @override
  List<Category> getCategoriesForAccount(String accountId) =>
      byAccount[accountId] ?? const [];

  @override
  bool hasLoadedAccount(String accountId) => true;

  @override
  Future<void> loadAvailableIcons() async {}
}

class _NoopExpensesService extends ExpensesService {}

class _NoopBudgetsService extends AccountBudgetsService {}

class _NoopCategoriesServiceForAccounts extends CategoriesService {}

void main() {
  late AccountsViewModel accountsViewModel;

  setUp(() {
    accountsViewModel = AccountsViewModel(
      accountsService: _FakeAccountsService()
        ..values = [Fixtures.account(id: 'a1', name: 'Compte courant')],
      categoriesService: _NoopCategoriesServiceForAccounts(),
      expensesService: _NoopExpensesService(),
      accountBudgetsService: _NoopBudgetsService(),
    );
  });

  tearDown(() => accountsViewModel.dispose());

  testWidgets('renders the injected categories view model instead of creating its own', (
    tester,
  ) async {
    final categoriesViewModel = CategoriesViewModel(
      categoriesService: _FakeCategoriesService({
        'a1': [Fixtures.category(id: 'c1', accountId: 'a1', name: 'Courses')],
      }),
      expensesService: _NoopExpensesService(),
    );

    await pumpApp(
      tester,
      CategoriesTab(
        accountsViewModel: accountsViewModel,
        injectedCategoriesViewModel: categoriesViewModel,
      ),
    );
    await tester.pump();

    expect(find.text('Courses'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    categoriesViewModel.dispose();
  });

  testWidgets('unmounting the tab does not dispose an injected categories view model', (
    tester,
  ) async {
    final categoriesViewModel = CategoriesViewModel(
      categoriesService: _FakeCategoriesService({
        'a1': [Fixtures.category(id: 'c1', accountId: 'a1', name: 'Courses')],
      }),
      expensesService: _NoopExpensesService(),
    );

    await pumpApp(
      tester,
      CategoriesTab(
        accountsViewModel: accountsViewModel,
        injectedCategoriesViewModel: categoriesViewModel,
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    expect(categoriesViewModel.isDisposed, isFalse);

    categoriesViewModel.dispose();
  });
}
