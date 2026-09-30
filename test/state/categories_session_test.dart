import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';

class _FakeCategoriesService extends CategoriesService {
  _FakeCategoriesService(this.values)
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );

  final List<Category> values;
  bool shouldFailLoad = false;
  int invalidateAccountCalls = 0;
  int invalidateCacheCalls = 0;

  void Function(List<Category>)? _lastOnRevalidated;

  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
    void Function(List<Category>)? onRevalidated,
  }) async {
    _lastOnRevalidated = onRevalidated;
    if (shouldFailLoad) throw Exception('boom');
    return values.where((c) => c.accountId == accountId).toList();
  }

  /// Invokes the `onRevalidated` callback the session passed on the most
  /// recent `listCategoriesByAccount` call, as `CategoriesService` itself
  /// would once its background revalidation completes.
  void simulateBackgroundRevalidation(List<Category> serverCategories) {
    _lastOnRevalidated?.call(serverCategories);
  }

  @override
  Future<List<CategoryIcon>> loadAvailableIcons() async => [
    Fixtures.categoryIcon(),
  ];

  @override
  Future<Category> createCategory(Category category) async {
    values.add(category);
    return category;
  }

  @override
  Future<Category> updateCategory(Category category) async {
    final index = values.indexWhere((c) => c.id == category.id);
    if (index != -1) values[index] = category;
    return category;
  }

  @override
  Future<bool> deleteCategory(String categoryId, {String? accountId}) async {
    values.removeWhere((c) => c.id == categoryId);
    return true;
  }

  @override
  void invalidateAccountCache(String accountId) => invalidateAccountCalls++;

  @override
  void invalidateCache() => invalidateCacheCalls++;
}

void main() {
  test('load populates categories for the given account only', () async {
    final service = _FakeCategoriesService([
      Fixtures.category(id: 'c1', accountId: 'a1'),
      Fixtures.category(id: 'c2', accountId: 'a2'),
    ]);
    final container = ProviderContainer(
      overrides: [categoriesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(categoriesSessionProvider.notifier);
    await notifier.load('a1');

    expect(notifier.hasLoadedAccount('a1'), isTrue);
    expect(notifier.hasLoadedAccount('a2'), isFalse);
    expect(notifier.getCategoriesForAccount('a1').map((c) => c.id), ['c1']);
  });

  test('a failing load leaves the previous state untouched', () async {
    final service = _FakeCategoriesService([
      Fixtures.category(id: 'c1', accountId: 'a1'),
    ]);
    final container = ProviderContainer(
      overrides: [categoriesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(categoriesSessionProvider.notifier);
    await notifier.load('a1');
    expect(notifier.getCategoriesForAccount('a1'), hasLength(1));

    service.shouldFailLoad = true;
    await expectLater(notifier.load('a1'), throwsException);

    expect(notifier.getCategoriesForAccount('a1'), hasLength(1));
  });

  test('loadIcons populates the shared icon list once', () async {
    final service = _FakeCategoriesService([]);
    final container = ProviderContainer(
      overrides: [categoriesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    expect(container.read(categoriesSessionProvider).iconsLoaded, isFalse);
    await container.read(categoriesSessionProvider.notifier).loadIcons();

    final state = container.read(categoriesSessionProvider);
    expect(state.iconsLoaded, isTrue);
    expect(state.availableIcons, hasLength(1));
  });

  test('create adds the category under its account', () async {
    final service = _FakeCategoriesService([]);
    final container = ProviderContainer(
      overrides: [categoriesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(categoriesSessionProvider.notifier);
    await notifier.create(Fixtures.category(id: 'c1', accountId: 'a1'));

    expect(notifier.getCategoriesForAccount('a1').map((c) => c.id), ['c1']);
  });

  test('update replaces the matching category in place', () async {
    final service = _FakeCategoriesService([
      Fixtures.category(id: 'c1', accountId: 'a1', name: 'Courses'),
    ]);
    final container = ProviderContainer(
      overrides: [categoriesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(categoriesSessionProvider.notifier);
    await notifier.load('a1');
    await notifier.update(
      Fixtures.category(id: 'c1', accountId: 'a1', name: 'Loisirs'),
    );

    expect(notifier.getCategoriesForAccount('a1').single.name, 'Loisirs');
  });

  test(
    'delete removes the category from every account it was cached under',
    () async {
      final service = _FakeCategoriesService([
        Fixtures.category(id: 'c1', accountId: 'a1'),
      ]);
      final container = ProviderContainer(
        overrides: [categoriesServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(categoriesSessionProvider.notifier);
      await notifier.load('a1');
      final deleted = await notifier.delete('c1', accountId: 'a1');

      expect(deleted, isTrue);
      expect(notifier.getCategoriesForAccount('a1'), isEmpty);
    },
  );

  test('RL-01 §3.2: a background revalidation reported by the service updates '
      'the shared state so listeners (Overview, ...) rebuild', () async {
    final service = _FakeCategoriesService([
      Fixtures.category(id: 'c1', accountId: 'a1'),
    ]);
    final container = ProviderContainer(
      overrides: [categoriesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(categoriesSessionProvider.notifier);
    await notifier.load('a1');
    expect(notifier.getCategoriesForAccount('a1').map((c) => c.id), ['c1']);

    service.simulateBackgroundRevalidation([
      Fixtures.category(id: 'c1', accountId: 'a1'),
      Fixtures.category(id: 'c2', accountId: 'a1'),
    ]);

    expect(
      notifier.getCategoriesForAccount('a1').map((c) => c.id),
      ['c1', 'c2'],
      reason:
          'the session must reflect the server-confirmed data, not stay '
          'frozen on the first cached snapshot',
    );
  });

  test(
    'invalidateAccount drops the cached account and forwards to the service',
    () async {
      final service = _FakeCategoriesService([
        Fixtures.category(id: 'c1', accountId: 'a1'),
      ]);
      final container = ProviderContainer(
        overrides: [categoriesServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(categoriesSessionProvider.notifier);
      await notifier.load('a1');
      notifier.invalidateAccount('a1');

      expect(notifier.hasLoadedAccount('a1'), isFalse);
      expect(service.invalidateAccountCalls, 1);
    },
  );

  test('clear resets everything and forwards to the service', () async {
    final service = _FakeCategoriesService([
      Fixtures.category(id: 'c1', accountId: 'a1'),
    ]);
    final container = ProviderContainer(
      overrides: [categoriesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(categoriesSessionProvider.notifier);
    await notifier.load('a1');
    notifier.clear();

    final state = container.read(categoriesSessionProvider);
    expect(state.categoriesByAccount, isEmpty);
    expect(state.loadedAccounts, isEmpty);
    expect(service.invalidateCacheCalls, 1);
  });
}
