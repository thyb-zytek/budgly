import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/pages/category_expenses/view.dart';
import 'package:budgly/src/pages/category_expenses/view_model.dart';
import 'package:budgly/src/pages/category_expenses/widgets/category_expenses_content.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';

class _NoopAccountsService extends AccountsService {
  final Account account;
  _NoopAccountsService(this.account);

  @override
  Account? getAccountById(String id) => id == account.id ? account : null;
}

class _NoopCategoriesService extends CategoriesService {
  final Category category;
  _NoopCategoriesService(this.category);

  @override
  bool hasLoadedAccount(String accountId) => true;

  @override
  Category? getCategoryById(String categoryId) =>
      categoryId == category.id ? category : null;

  @override
  List<Category> getCategoriesForAccount(String accountId) => [category];
}

class _NoopExpensesService extends ExpensesService {
  @override
  Future<ExpensePage> listCategoryPeriodPage(
    String accountId,
    String categoryId,
    Period period, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    bool includeRecurring = true,
  }) async => const ExpensePage(expenses: [], cursor: null, hasMore: false);
}

class _FakeProfileService extends ProfileService {
  @override
  String get currency => 'EUR';

  @override
  Locale get locale => const Locale('fr');

  @override
  int get amountDecimalPlaces => 2;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

Future<CategoryExpensesViewModel> _buildLoadedViewModel() async {
  final account = Fixtures.account(id: 'a1', name: 'Compte courant');
  final category = Fixtures.category(id: 'c1', accountId: 'a1', name: 'Courses');
  final viewModel = CategoryExpensesViewModel(
    accountId: 'a1',
    categoryId: 'c1',
    period: const Period(year: 2026, month: 9),
    expensesService: _NoopExpensesService(),
    categoriesService: _NoopCategoriesService(category),
    profileService: _FakeProfileService(),
    accountsService: _NoopAccountsService(account),
  );
  await viewModel.ensureDataLoaded();
  return viewModel;
}

Future<void> _pumpCategoryExpensesPage(
  WidgetTester tester,
  CategoryExpensesViewModel viewModel,
) async {
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
      home: CategoryExpensesPage(
        accountId: 'a1',
        categoryId: 'c1',
        period: const Period(year: 2026, month: 9),
        injectedViewModel: viewModel,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders the injected view model\'s category instead of creating its own', (
    tester,
  ) async {
    final viewModel = await _buildLoadedViewModel();

    await _pumpCategoryExpensesPage(tester, viewModel);

    expect(find.text('Courses'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) => w is CategoryExpensesContent && w.viewModel == viewModel,
      ),
      findsOneWidget,
    );

    viewModel.dispose();
  });

  testWidgets('unmounting the page does not dispose an injected view model', (
    tester,
  ) async {
    final viewModel = await _buildLoadedViewModel();

    await _pumpCategoryExpensesPage(tester, viewModel);
    await tester.pumpWidget(const SizedBox.shrink());

    expect(viewModel.isDisposed, isFalse);

    viewModel.dispose();
  });
}
