import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/pages/settings/categories/view_model.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/builders.dart';
import '../../../helpers/fake_stores.dart';

class FakeCategoriesService extends CategoriesService {
  final Map<String, List<Category>> byAccount = {};
  final Set<String> loadedAccounts = {};
  List<CategoryIcon> icons = [Fixtures.categoryIcon()];
  int deleteCalls = 0;
  bool failLoadIcons = false;
  Object? createError;
  Object? updateError;
  Object? deleteError;
  Category? created;
  Category? updated;

  @override
  List<CategoryIcon> get availableIcons => icons;

  @override
  List<Category> getCategoriesForAccount(String accountId) =>
      byAccount[accountId] ?? const [];

  @override
  bool hasLoadedAccount(String accountId) => loadedAccounts.contains(accountId);

  @override
  Future<void> loadAvailableIcons() async {
    if (failLoadIcons) throw StateError('network connection lost');
    icons = [Fixtures.categoryIcon()];
  }

  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async {
    loadedAccounts.add(accountId);
    return byAccount[accountId] ?? const [];
  }

  @override
  Future<Category> createCategory(Category category) async {
    if (createError != null) throw createError!;
    created = category;
    return category;
  }

  @override
  Future<Category> updateCategory(Category category) async {
    if (updateError != null) throw updateError!;
    updated = category;
    return category;
  }

  @override
  Future<bool> deleteCategory(String categoryId) async {
    if (deleteError != null) throw deleteError!;
    deleteCalls++;
    return true;
  }
}

class FakeExpensesServiceForCategories extends ExpensesService {
  int deleteByCategoryCalls = 0;
  bool failDelete = false;

  @override
  Future<void> deleteByCategoryId(String categoryId) async {
    if (failDelete) throw StateError('offline');
    deleteByCategoryCalls++;
  }
}

void main() {
  late FakeCategoriesService cats;
  late FakeExpensesServiceForCategories expenses;

  setUp(() {
    clearAllTestStores();
    cats = FakeCategoriesService();
    expenses = FakeExpensesServiceForCategories();
  });

  tearDown(clearAllTestStores);

  test('categories getter returns empty when no account is selected', () {
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);

    expect(vm.categories, isEmpty);
    expect(vm.hasCategoriesLoaded, isFalse);
    expect(vm.isCreatingCategory, isFalse);
  });

  test('setting account loads categories when not yet loaded', () async {
    final account = Fixtures.account(id: 'a1');
    cats.byAccount['a1'] = [Fixtures.category(id: 'c1', accountId: 'a1')];
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);

    vm.account = account;
    await Future<void>.delayed(Duration.zero);

    expect(vm.account, account);
    expect(vm.hasCategoriesLoaded, isTrue);
    expect(vm.categories.single.id, 'c1');
  });

  test('setting the same account is a no-op', () {
    final account = Fixtures.account(id: 'a1');
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.account = account;
    var notified = false;
    vm.addListener(() => notified = true);

    vm.account = account;

    expect(notified, isFalse);
  });

  test('editingCategory populates the name, color, and icon', () {
    final icon = Fixtures.categoryIcon();
    final category = Fixtures.category(id: 'c1', accountId: 'a1', icon: icon);
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);

    vm.editingCategory = category;

    expect(vm.editingCategory?.id, 'c1');
    expect(vm.categoryEditingData.nameController.text, 'Courses');
    expect(vm.categoryEditingData.icon, icon);
  });

  test('editingCategory with null clears the form', () {
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.editingCategory = Fixtures.category(id: 'c1', accountId: 'a1');
    vm.categoryEditingData.nameController.text = 'Foo';

    vm.editingCategory = null;

    expect(vm.categoryEditingData.nameController.text, isEmpty);
  });

  test('cancelEdit clears the editing category and name', () {
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.editingCategory = Fixtures.category(id: 'c1', accountId: 'a1');

    vm.cancelEdit();

    expect(vm.editingCategory, isNull);
    expect(vm.categoryEditingData.nameController.text, isEmpty);
  });

  test('loadCategories loads icons and categories', () async {
    final account = Fixtures.account(id: 'a1');
    cats.byAccount['a1'] = [Fixtures.category(id: 'c1', accountId: 'a1')];
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.account = account;

    await vm.loadCategories();

    expect(vm.hasCategoriesLoaded, isTrue);
    expect(vm.categories.single.id, 'c1');
    expect(vm.viewState, ViewState.success);
  });

  test('loadCategories is a no-op when no account is selected', () async {
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);

    await vm.loadCategories();

    expect(vm.viewState, ViewState.idle);
  });

  test('loadCategories suppresses offline icon errors', () async {
    final account = Fixtures.account(id: 'a1');
    cats.failLoadIcons = true;
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.account = account;

    await vm.loadCategories();

    expect(vm.hasError, isFalse);
    expect(vm.viewState, ViewState.success);
  });

  test('addCategory creates a local draft category with available icons', () async {
    final account = Fixtures.account(id: 'a1');
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.account = account;

    await vm.addCategory();

    expect(vm.isCreatingCategory, isTrue);
    expect(vm.categories, hasLength(1));
    expect(vm.categories.single.id, isNull);
    expect(vm.categoryEditingData.availableIcons, isNotEmpty);
  });

  test('addCategory is a no-op when no account is selected', () async {
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);

    await vm.addCategory();

    expect(vm.isCreatingCategory, isFalse);
  });

  test('removeCategory removes a local draft without calling the service', () async {
    final account = Fixtures.account(id: 'a1');
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.account = account;
    vm.categoryEditingData.nameController.text = 'X';
    vm.categoryEditingData.color = const Color(0xFF112233);

    await vm.addCategory();
    final draft = vm.categories.single;

    vm.removeCategory(draft);

    expect(vm.categories, isEmpty);
    expect(cats.deleteCalls, 0);
  });

  test('removeCategory deletes expenses and category from the services', () async {
    final account = Fixtures.account(id: 'a1');
    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.account = account;

    await vm.removeCategory(category);

    expect(expenses.deleteByCategoryCalls, 1);
    expect(cats.deleteCalls, 1);
    expect(vm.pendingUserMessage, isNotNull);
    expect(vm.viewState, ViewState.success);
  });

  test('createCategory creates through the service and clears the draft', () async {
    final account = Fixtures.account(id: 'a1');
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.account = account;
    await vm.addCategory();
    final draft = vm.categories.single;
    vm.categoryEditingData.nameController.text = 'Shopping';

    await vm.createCategory(draft);

    expect(cats.created?.name, 'Shopping');
    expect(cats.created?.accountId, 'a1');
    expect(vm.isCreatingCategory, isFalse);
    expect(vm.pendingUserMessage, isNotNull);
  });

  test('createCategory is a no-op when no account is selected', () async {
    final draft = Fixtures.category(id: null, accountId: 'a1');
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);

    await vm.createCategory(draft);

    expect(cats.created, isNull);
  });

  test('updateCategory updates through the service', () async {
    final account = Fixtures.account(id: 'a1');
    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.account = account;
    vm.editingCategory = category;
    vm.categoryEditingData.nameController.text = 'Renamed';

    await vm.updateCategory(category);

    expect(cats.updated?.name, 'Renamed');
    expect(vm.pendingUserMessage, isNotNull);
  });

  test('createCategory reports an error when the service fails', () async {
    final account = Fixtures.account(id: 'a1');
    cats.createError = Exception('boom');
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.account = account;
    await vm.addCategory();
    final draft = vm.categories.single;

    await vm.createCategory(draft);

    expect(vm.hasError, isTrue);
    expect(vm.viewState, ViewState.error);
  });

  test('updateCategory reports an error when the service fails', () async {
    final account = Fixtures.account(id: 'a1');
    cats.updateError = Exception('boom');
    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.account = account;
    vm.editingCategory = category;

    await vm.updateCategory(category);

    expect(vm.hasError, isTrue);
  });

  test('removeCategory reports an error when the service fails', () async {
    final account = Fixtures.account(id: 'a1');
    cats.deleteError = Exception('boom');
    final category = Fixtures.category(id: 'c1', accountId: 'a1');
    final vm = CategoriesViewModel(categoriesService: cats, expensesService: expenses);
    addTearDown(vm.dispose);
    vm.account = account;

    await vm.removeCategory(category);

    expect(vm.hasError, isTrue);
  });
}
