import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/settings/accounts/tab.dart';
import 'package:budgly/src/pages/settings/accounts/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
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

class _NoopCategoriesService extends CategoriesService {}

class _NoopExpensesService extends ExpensesService {}

class _NoopBudgetsService extends AccountBudgetsService {}

void main() {
  late _FakeAccountsService fakeAccountsService;
  late AccountsViewModel accountsViewModel;

  setUp(() {
    fakeAccountsService = _FakeAccountsService();
    accountsViewModel = AccountsViewModel(
      accountsService: fakeAccountsService,
      categoriesService: _NoopCategoriesService(),
      expensesService: _NoopExpensesService(),
      accountBudgetsService: _NoopBudgetsService(),
    );
  });

  tearDown(() => accountsViewModel.dispose());

  testWidgets('renders the list of accounts with their names', (tester) async {
    fakeAccountsService.values = [
      Fixtures.account(id: 'a1', name: 'Compte courant'),
      Fixtures.account(id: 'a2', name: 'Épargne'),
    ];

    await pumpApp(tester, AccountsTab(accountsViewModel: accountsViewModel));

    expect(find.text('Compte courant'), findsOneWidget);
    expect(find.text('Épargne'), findsOneWidget);
  });

  testWidgets('shows the empty message when no account exists', (tester) async {
    await pumpApp(tester, AccountsTab(accountsViewModel: accountsViewModel));

    expect(find.textContaining('Aucun compte trouvé'), findsOneWidget);
  });

  testWidgets('always offers the add-account entry point', (tester) async {
    await pumpApp(tester, AccountsTab(accountsViewModel: accountsViewModel));

    expect(find.text('Nouveau compte'), findsOneWidget);
  });
}