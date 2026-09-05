import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/pages/overview/overview_repository.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/pages/overview/widgets/revenue_form.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/builders.dart';
import '../../../helpers/fake_stores.dart';
import '../../../helpers/pump_app.dart';

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

class _FakeBudgetsService extends AccountBudgetsService {
  final Map<String, double> values = {};
  final Set<String> loaded = {};
  double? lastSetRevenue;

  String _key(String accountId, int year, int month) => '$accountId-$year-$month';

  @override
  bool hasLoaded(String accountId, int year, int month) =>
      loaded.contains(_key(accountId, year, month));

  @override
  Future<void> loadRevenue(
    String accountId,
    int year,
    int month, {
    bool forceRefresh = false,
  }) async {
    loaded.add(_key(accountId, year, month));
  }

  @override
  double getRevenue(String accountId, int year, int month) =>
      values[_key(accountId, year, month)] ?? 0;

  @override
  Future<void> setRevenue(
    String accountId,
    int year,
    int month,
    double value,
  ) async {
    lastSetRevenue = value;
    values[_key(accountId, year, month)] = value;
    loaded.add(_key(accountId, year, month));
  }
}

class _FakeOverviewRepository extends OverviewRepository {
  double? inheritedRevenue;

  @override
  Future<List<Expense>> loadInitialData(Account account, Period period) async =>
      const [];

  @override

  @override
  Future<double?> getMostRecentRevenue(
    String accountId, {
    required Period before,
  }) async => inheritedRevenue;
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

void main() {
  late _FakeBudgetsService budgets;
  late _FakeOverviewRepository repository;
  late OverviewViewModel viewModel;

  setUp(() {
    clearAllTestStores();
    Fixtures.resetSeq();
    budgets = _FakeBudgetsService();
    repository = _FakeOverviewRepository();
  });

  tearDown(() {
    viewModel.dispose();
    clearAllTestStores();
  });

  // Inherited-revenue lookups are cached even when they resolve to null, so
  // any test that cares about a specific `repository.inheritedRevenue` value
  // must set it *before* the first loadInitialData() call for that account
  // and period — a second call would just return the cached result.
  Future<void> buildViewModel() async {
    viewModel = OverviewViewModel(
      accountsService: _NoopAccountsService([Fixtures.account(id: 'a1')]),
      categoriesService: _NoopCategoriesService(),
      expensesService: _NoopExpensesService(),
      accountBudgetsService: budgets,
      profileService: _FakeProfileService(),
      repository: repository,
    );
    await viewModel.loadInitialData();
  }

  testWidgets('starts blank when there is no revenue and nothing inherited', (
    tester,
  ) async {
    await buildViewModel();
    await pumpApp(tester, RevenueForm(viewModel: viewModel, onClose: () {}));

    expect(find.text('Aucun revenu défini pour cette période — le plus récent est utilisé comme estimation'), findsNothing);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('pre-fills with the inherited revenue and shows the estimate hint', (
    tester,
  ) async {
    repository.inheritedRevenue = 1500;
    await buildViewModel();

    await pumpApp(tester, RevenueForm(viewModel: viewModel, onClose: () {}));

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, '1500');
    expect(find.text('Aucun revenu défini pour cette période — le plus récent est utilisé comme estimation'), findsOneWidget);
  });

  testWidgets('submitting a value calls setRevenue and onClose', (
    tester,
  ) async {
    await buildViewModel();
    var closed = false;
    await pumpApp(
      tester,
      RevenueForm(viewModel: viewModel, onClose: () => closed = true),
    );

    await tester.enterText(find.byType(TextFormField), '2000');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(budgets.lastSetRevenue, 2000);
    expect(closed, isTrue);
  });

  testWidgets('submitting a blank value saves zero instead of crashing', (
    tester,
  ) async {
    await buildViewModel();
    var closed = false;
    await pumpApp(
      tester,
      RevenueForm(viewModel: viewModel, onClose: () => closed = true),
    );

    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(budgets.lastSetRevenue, 0);
    expect(closed, isTrue);
  });

  testWidgets('tapping cancel calls onClose without saving anything', (
    tester,
  ) async {
    await buildViewModel();
    var closed = false;
    await pumpApp(
      tester,
      RevenueForm(viewModel: viewModel, onClose: () => closed = true),
    );

    await tester.enterText(find.byType(TextFormField), '2000');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(budgets.lastSetRevenue, isNull);
    expect(closed, isTrue);
  });
}
