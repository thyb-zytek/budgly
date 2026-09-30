import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/pages/settings/categories/categories_settings_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/builders.dart';
import '../../../helpers.dart';

/// Complements `categories_settings_provider_test.dart` (a single regression
/// test for `removeCategory`'s success path) with `loadCategories`'s two
/// distinct error branches (network vs other -- the notifier deliberately
/// treats them differently), and the untested success/error branches of
/// `removeCategory`, `createCategory` and `updateCategory`.
///
/// `selectAccount` fires its own background `loadCategories()` call whenever
/// the account isn't already marked loaded in `CategoriesSession`. Every test
/// below primes that state first (`_primeAccountAsLoaded`) so `selectAccount`
/// never races with the explicit, fully-controlled `loadCategories()` call
/// each test actually wants to observe.
class _ScriptedCategoriesService extends CategoriesService {
  _ScriptedCategoriesService({List<Category> categories = const []})
    : _categories = List.of(categories),
      super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );

  final List<Category> _categories;
  Object? loadError;
  Object? deleteError;
  Object? createError;
  Object? updateError;

  @override
  Future<List<CategoryIcon>> loadAvailableIcons() async => const [];

  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
    void Function(List<Category>)? onRevalidated,
  }) async {
    if (loadError != null) throw loadError!;
    return _categories.where((c) => c.accountId == accountId).toList();
  }

  @override
  Future<bool> deleteCategory(String categoryId, {String? accountId}) async {
    if (deleteError != null) throw deleteError!;
    _categories.removeWhere((c) => c.id == categoryId);
    return true;
  }

  @override
  Future<Category> createCategory(Category category) async {
    if (createError != null) throw createError!;
    final created = category.id == null
        ? category.copyWith(id: 'new-id')
        : category;
    _categories.add(created);
    return created;
  }

  @override
  Future<Category> updateCategory(Category category) async {
    if (updateError != null) throw updateError!;
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) _categories[index] = category;
    return category;
  }
}

class _NoOpExpensesService extends ExpensesService {
  _NoOpExpensesService() : super(analytics: AnalyticsService());

  @override
  Future<void> deleteByCategoryId(String categoryId) async {}
}

ProviderContainer _makeContainer(_ScriptedCategoriesService service) =>
    ProviderContainer(
      overrides: [
        categoriesServiceProvider.overrideWithValue(service),
        expensesServiceProvider.overrideWithValue(_NoOpExpensesService()),
      ],
    );

/// Marks [accountId] as already loaded in `CategoriesSession`, so a later
/// `selectAccount` call does not also fire its own background
/// `loadCategories()` (see the file-level doc comment).
Future<void> _primeAccountAsLoaded(
  ProviderContainer container,
  String accountId,
) => container.read(categoriesSessionProvider.notifier).load(accountId);

void main() {
  group('loadCategories', () {
    test(
      'a successful load publishes the icons and clears the loading status',
      () async {
        final category = Fixtures.category(id: 'c1', accountId: 'a1');
        final service = _ScriptedCategoriesService(categories: [category]);
        final container = _makeContainer(service);
        addTearDown(container.dispose);
        await _primeAccountAsLoaded(container, 'a1');

        final notifier = container.read(categoriesSettingsProvider.notifier);
        notifier.selectAccount(const Account(id: 'a1', name: 'Main'));
        await notifier.loadCategories();

        final state = container.read(categoriesSettingsProvider);
        expect(state.status.isLoading, isFalse);
        expect(state.status.hasError, isFalse);
      },
    );

    test(
      'a network failure is treated as merely offline, not an error',
      () async {
        final service = _ScriptedCategoriesService();
        final container = _makeContainer(service);
        addTearDown(container.dispose);
        await _primeAccountAsLoaded(container, 'a1');

        final notifier = container.read(categoriesSettingsProvider.notifier);
        notifier.selectAccount(const Account(id: 'a1', name: 'Main'));
        service.loadError = Exception('SocketException: Failed host lookup');
        await notifier.loadCategories();

        final state = container.read(categoriesSettingsProvider);
        expect(
          state.status.hasError,
          isFalse,
          reason:
              'a network failure while offline must not surface as a screen-level error',
        );
        expect(state.status.isLoading, isFalse);
      },
    );

    test(
      'a non-network failure does surface as a screen-level error',
      () async {
        final service = _ScriptedCategoriesService();
        final container = _makeContainer(service);
        addTearDown(container.dispose);
        await _primeAccountAsLoaded(container, 'a1');

        final notifier = container.read(categoriesSettingsProvider.notifier);
        notifier.selectAccount(const Account(id: 'a1', name: 'Main'));
        service.loadError = StateError('boom');
        await notifier.loadCategories();

        final state = container.read(categoriesSettingsProvider);
        expect(state.status.hasError, isTrue);
      },
    );
  });

  group('removeCategory', () {
    test('a failure reports a screen-level error', () async {
      final category = Fixtures.category(id: 'c1', accountId: 'a1');
      final service = _ScriptedCategoriesService(categories: [category]);
      final container = _makeContainer(service);
      addTearDown(container.dispose);
      await _primeAccountAsLoaded(container, 'a1');

      service.deleteError = StateError('boom');
      await container
          .read(categoriesSettingsProvider.notifier)
          .removeCategory(category);

      expect(
        container.read(categoriesSettingsProvider).status.hasError,
        isTrue,
      );
    });
  });

  group('createCategory', () {
    test(
      'a successful create clears the local draft and reports success',
      () async {
        final service = _ScriptedCategoriesService();
        final container = _makeContainer(service);
        addTearDown(container.dispose);
        await _primeAccountAsLoaded(container, 'a1');

        final notifier = container.read(categoriesSettingsProvider.notifier);
        notifier.selectAccount(const Account(id: 'a1', name: 'Main'));
        final draft = await notifier.addCategory();
        expect(draft, isNotNull);
        expect(container.read(categoriesSettingsProvider).localCategories, [
          draft,
        ]);

        await notifier.createCategory(
          draft: draft!,
          name: 'Courses',
          color: Colors.green,
          icon: draft.icon!,
          monthlyThreshold: '200',
        );

        final state = container.read(categoriesSettingsProvider);
        expect(state.localCategories, isEmpty);
        expect(state.editingCategory, isNull);
        expect(state.status.hasError, isFalse);
      },
    );

    test(
      'a failure reports a screen-level error and keeps the local draft',
      () async {
        final service = _ScriptedCategoriesService();
        final container = _makeContainer(service);
        addTearDown(container.dispose);
        await _primeAccountAsLoaded(container, 'a1');

        final notifier = container.read(categoriesSettingsProvider.notifier);
        notifier.selectAccount(const Account(id: 'a1', name: 'Main'));
        final draft = await notifier.addCategory();

        service.createError = StateError('boom');
        await notifier.createCategory(
          draft: draft!,
          name: 'Courses',
          color: Colors.green,
          icon: draft.icon!,
          monthlyThreshold: '200',
        );

        final state = container.read(categoriesSettingsProvider);
        expect(state.status.hasError, isTrue);
        // The failed draft is not silently discarded: the user can retry it.
        expect(state.localCategories, [draft]);
      },
    );
  });

  group('updateCategory', () {
    test('a successful update clears editing and reports success', () async {
      final category = Fixtures.category(
        id: 'c1',
        accountId: 'a1',
        name: 'Old',
      );
      final service = _ScriptedCategoriesService(categories: [category]);
      final container = _makeContainer(service);
      addTearDown(container.dispose);
      await _primeAccountAsLoaded(container, 'a1');

      final notifier = container.read(categoriesSettingsProvider.notifier);
      notifier.selectAccount(const Account(id: 'a1', name: 'Main'));
      notifier.setEditingCategory(category);

      await notifier.updateCategory(
        category: category,
        name: 'New',
        color: Colors.blue,
        icon: category.icon!,
        monthlyThreshold: '150',
      );

      final state = container.read(categoriesSettingsProvider);
      expect(state.editingCategory, isNull);
      expect(state.status.hasError, isFalse);
    });

    test('a failure reports a screen-level error', () async {
      final category = Fixtures.category(id: 'c1', accountId: 'a1');
      final service = _ScriptedCategoriesService(categories: [category]);
      final container = _makeContainer(service);
      addTearDown(container.dispose);
      await _primeAccountAsLoaded(container, 'a1');

      final notifier = container.read(categoriesSettingsProvider.notifier);
      notifier.selectAccount(const Account(id: 'a1', name: 'Main'));
      notifier.setEditingCategory(category);

      service.updateError = StateError('boom');
      await notifier.updateCategory(
        category: category,
        name: 'New',
        color: Colors.blue,
        icon: category.icon!,
        monthlyThreshold: '150',
      );

      expect(
        container.read(categoriesSettingsProvider).status.hasError,
        isTrue,
      );
    });
  });
}
