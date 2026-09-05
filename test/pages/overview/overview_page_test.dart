import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/pages/overview/overview_repository.dart';
import 'package:budgly/src/pages/overview/view.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/pages/overview/widgets/overview_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';
import '../../helpers/fake_stores.dart';

class _NoopAccountsService extends AccountsService {
  final List<Account> values;
  _NoopAccountsService(this.values);

  @override
  List<Account> get accounts => values;

  @override
  bool get hasLoaded => true;

  @override
  Future<void> loadAccounts({bool forceRefresh = false}) async {}
}

class _NoopCategoriesService extends CategoriesService {
  @override
  List<Category> getCategoriesForAccount(String accountId) => const [];
}

class _NoopExpensesService extends ExpensesService {}

class _NoopBudgetsService extends AccountBudgetsService {}

class _NoopOverviewRepository extends OverviewRepository {
  @override
  Future<List<Expense>> loadInitialData(Account account, Period period) async =>
      const [];

  @override

  @override
  Future<double?> getMostRecentRevenue(
    String accountId, {
    required Period before,
  }) async => null;
}

class _FakeProfileService extends ProfileService {
  @override
  String get currency => 'EUR';

  @override
  int get amountDecimalPlaces => 2;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

Future<OverviewViewModel> _buildLoadedViewModel() async {
  final viewModel = OverviewViewModel(
    accountsService: _NoopAccountsService([
      Fixtures.account(id: 'a1', name: 'Compte courant'),
    ]),
    categoriesService: _NoopCategoriesService(),
    expensesService: _NoopExpensesService(),
    accountBudgetsService: _NoopBudgetsService(),
    profileService: _FakeProfileService(),
    repository: _NoopOverviewRepository(),
  );
  await viewModel.loadInitialData();
  return viewModel;
}

Future<void> _pumpOverviewPage(
  WidgetTester tester,
  OverviewViewModel viewModel,
) async {
  await tester.binding.setSurfaceSize(const Size(360, 740));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fr')],
      theme: ThemeData.light(useMaterial3: true),
      home: OverviewPage(injectedViewModel: viewModel),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    clearAllTestStores();
    Fixtures.resetSeq();
  });

  tearDown(clearAllTestStores);

  testWidgets('renders the injected view model\'s account instead of creating its own', (
    tester,
  ) async {
    final viewModel = await _buildLoadedViewModel();

    await _pumpOverviewPage(tester, viewModel);

    expect(
      find.byWidgetPredicate(
        (w) => w is OverviewContent && w.viewModel == viewModel,
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
  });

  testWidgets('unmounting the page does not dispose an injected view model', (
    tester,
  ) async {
    final viewModel = await _buildLoadedViewModel();

    await _pumpOverviewPage(tester, viewModel);
    await tester.pumpWidget(const SizedBox.shrink());

    expect(viewModel.isDisposed, isFalse);

    viewModel.dispose();
  });
}
