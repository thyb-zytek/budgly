import 'dart:ui';

import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/pages/tutorial/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';
import '../../helpers/fake_stores.dart';


class FakeTutorialAuthService extends AuthService {
  final User? user;
  FakeTutorialAuthService(this.user);
  @override
  User? get currentUser => user;
}

class FakeTutorialAccountsService extends AccountsService {
  final List<Account> seeded;
  FakeTutorialAccountsService(this.seeded);
  @override
  List<Account> get accounts => seeded;
  @override
  Future<void> loadAccounts({bool forceRefresh = false}) async {}
}

class FakeTutorialCategoriesService extends CategoriesService {
  final List<CategoryIcon> icons;
  final Map<String, List<Category>> categories;
  FakeTutorialCategoriesService({this.icons = const [], this.categories = const {}});
  @override
  List<CategoryIcon> get availableIcons => icons;
  @override
  Future<void> loadAvailableIcons() async {}
  @override
  Future<List<Category>> listCategoriesByAccount(String accountId, {bool forceRefresh = false}) async => categories[accountId] ?? const [];
}

class FakeTutorialBudgetService extends AccountBudgetsService {
  final Map<String, double> revenues;
  FakeTutorialBudgetService([this.revenues = const {}]);
  String _key(String accountId, int year, int month) => '$accountId-$year-$month';
  @override
  Future<void> loadRevenue(String accountId, int year, int month, {bool forceRefresh = false}) async {}
  @override
  double getRevenue(String accountId, int year, int month) => revenues[_key(accountId, year, month)] ?? 0;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clearAllTestStores();
    Fixtures.resetSeq();
  });

  tearDown(clearAllTestStores);

  test('new tutorial starts at step zero and exposes default account/category state', () async {
    final vm = TutorialViewModel(
      accountsService: FakeTutorialAccountsService(const []),
      categoriesService: FakeTutorialCategoriesService(
        icons: [Fixtures.categoryIcon(iconName: 'groceries')],
      ),
      budgetService: FakeTutorialBudgetService(),
      profileService: ProfileService(),
    );
    addTearDown(vm.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(vm.currentStep, 0);
    expect(vm.totalSteps, 4);
    expect(vm.canGoBack, isFalse);
    expect(vm.isAccountValid, isFalse);
    expect(vm.isCategoryValid, isFalse);
    expect(vm.availableIcons, hasLength(1));
    expect(vm.isInitializing, isFalse);
  });

  test('step navigation is bounded and persists the current step', () async {
    final vm = TutorialViewModel(
      authService: FakeTutorialAuthService(null),
      accountsService: FakeTutorialAccountsService(const []),
      categoriesService: FakeTutorialCategoriesService(),
      budgetService: FakeTutorialBudgetService(),
      profileService: ProfileService(),
    );
    addTearDown(vm.dispose);
    await Future<void>.delayed(Duration.zero);

    vm.nextStep();
    vm.nextStep();
    vm.nextStep();
    vm.nextStep();
    expect(vm.currentStep, 3);
    expect(vm.canGoBack, isTrue);

    vm.previousStep();
    expect(vm.currentStep, 2);
    vm.previousStep();
    vm.previousStep();
    vm.previousStep();
    expect(vm.currentStep, 0);
    expect(vm.canGoBack, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('tutorial_step_anonymous'), 0);
  });

  test('existing account is adopted and its categories/revenue prefill the tutorial', () async {
    final account = Fixtures.account(id: 'a1', name: 'Compte existant');
    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    final vm = TutorialViewModel(
      authService: FakeTutorialAuthService(null),
      accountsService: FakeTutorialAccountsService([account]),
      categoriesService: FakeTutorialCategoriesService(
        icons: [Fixtures.categoryIcon()],
        categories: {'a1': [category]},
      ),
      budgetService: FakeTutorialBudgetService({'a1-${DateTime.now().year}-${DateTime.now().month}': 1800}),
      profileService: ProfileService(),
    );
    addTearDown(vm.dispose);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(vm.createdAccount?.id, 'a1');
    expect(vm.accountNameController.text, 'Compte existant');
    expect(vm.createdCategories.map((c) => c.id), ['c1']);
    expect(vm.hasCategories, isTrue);
    expect(vm.hasRevenue, isTrue);
    expect(vm.currentStep, 1);
  });

  test('account and category setters update editing state and validity', () async {
    final vm = TutorialViewModel(
      accountsService: FakeTutorialAccountsService(const []),
      categoriesService: FakeTutorialCategoriesService(icons: [Fixtures.categoryIcon()]),
      budgetService: FakeTutorialBudgetService(),
      profileService: ProfileService(),
    );
    addTearDown(vm.dispose);
    await Future<void>.delayed(Duration.zero);

    vm.accountNameController.text = 'Épargne';
    vm.categoryNameController.text = 'Transport';
    vm.setAccountColor(const Color(0xFF123456));
    vm.setCategoryColor(const Color(0xFF654321));
    vm.setCategoryIcon(Fixtures.categoryIcon(iconName: 'car'));

    expect(vm.isAccountValid, isTrue);
    expect(vm.isCategoryValid, isTrue);
    expect(vm.accountColor, const Color(0xFF123456));
    expect(vm.categoryColor, const Color(0xFF654321));
    expect(vm.categoryIcon?.iconName, 'car');
    expect(vm.accountInitial, 'É');
  });
}
