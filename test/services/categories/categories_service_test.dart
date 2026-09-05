import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/category_icons_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/supabase/categories.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';

class FakeCategorySupabase extends CategorySupabase {
  final List<Category> server = [];
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  Object? createError;
  Object? updateError;
  Object? listError;
  bool returnNullOnUpdate = false;

  @override
  Future<List<Category>> listByAccountId(String accountId) async {
    if (listError != null) throw listError!;
    return server.where((c) => c.accountId == accountId).toList();
  }

  @override
  Future<Category?> create(Category category) async {
    createCalls++;
    if (createError != null) throw createError!;
    server.removeWhere((c) => c.id == category.id);
    server.add(category);
    return category;
  }

  @override
  Future<Category?> update(Category category) async {
    updateCalls++;
    if (updateError != null) throw updateError!;
    if (returnNullOnUpdate) return null;
    server.removeWhere((c) => c.id == category.id);
    server.add(category);
    return category;
  }

  @override
  Future<bool> delete(String categoryId) async {
    deleteCalls++;
    server.removeWhere((c) => c.id == categoryId);
    return true;
  }
}

class FakeCategoryIconsService extends CategoryIconsService {
  final List<CategoryIcon> icons;
  FakeCategoryIconsService(this.icons);

  @override
  Future<List<CategoryIcon>> getIcons() async => List.unmodifiable(icons);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCategorySupabase supabase;
  late FakeCategoryIconsService iconsService;
  late CategoriesService service;

  final groceryIcon = Fixtures.categoryIcon();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    CategoriesStore.instance.clearAll();
    supabase = FakeCategorySupabase();
    iconsService = FakeCategoryIconsService([groceryIcon]);
    service = CategoriesService(
      categorySupabase: supabase,
      categoryIconsService: iconsService,
    );
  });

  tearDown(() async {
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    CategoriesStore.instance.clearAll();
  });

  test('loadAvailableIcons seeds the store only once', () async {
    await service.loadAvailableIcons();

    expect(service.availableIcons.single.iconName, 'groceries');
    expect(CategoriesStore.instance.iconsLoaded, isTrue);

    await service.loadAvailableIcons();
    expect(service.availableIcons, hasLength(1));
  });

  test('listCategoriesByAccount loads and caches remote categories', () async {
    final remote = [
      Fixtures.category(id: 'c1', accountId: 'a1', name: 'Courses'),
    ];
    supabase.server.addAll(remote);

    final result = await service.listCategoriesByAccount('a1');

    expect(result.single.id, 'c1');
    expect(service.hasLoadedAccount('a1'), isTrue);
    expect(service.getCategoriesForAccount('a1').single.name, 'Courses');
  });

  test('listCategoriesByAccount falls back to cache when remote fails', () async {
    CategoriesStore.instance.setCategoriesForAccount('a1', [
      Fixtures.category(id: 'c1', accountId: 'a1', name: 'Courses', icon: groceryIcon),
    ]);
    CategoriesStore.instance.setAvailableIcons([groceryIcon]);
    supabase
      ..listError = Exception('boom')
      ..server.clear();

    final result = await service.listCategoriesByAccount('a1', forceRefresh: true);

    expect(result.single.id, 'c1');
  });

  test('createCategory persists optimistically and enqueues a create', () async {
    final category = Fixtures.category(accountId: 'a1', name: 'Loisir');

    final created = await service.createCategory(category);

    expect(created.id, isNotNull);
    expect(service.getCategoryById(created.id!)!.name, 'Loisir');
    expect(
      await SyncQueue.instance.hasPending(type: 'categories'),
      isTrue,
      reason: 'an optimistic create must be queued for replay',
    );
  });

  test('createCategory syncs to the server through the registered handler',
      () async {
    final category = Fixtures.category(id: 'c-x', accountId: 'a1', name: 'Loisir');

    final created = await service.createCategory(category);

    // Drain the unawaited background flush triggered by _queueAndFlush.
    await SyncManager.instance.flush();
    await SyncManager.instance.waitForIdle();

    expect(created.id, 'c-x');
    expect(supabase.createCalls, greaterThan(0));
    expect(
      supabase.server.any((c) => c.id == 'c-x' && c.name == 'Loisir'),
      isTrue,
    );
  });

  test('updateCategory updates the store and enqueues an update', () async {
    final category = Fixtures.category(id: 'c1', accountId: 'a1', name: 'Avant');
    CategoriesStore.instance.addCategory(category);

    final updated = await service.updateCategory(category.copyWith(name: 'Après'));

    expect(updated.name, 'Après');
    expect(service.getCategoryById('c1')!.name, 'Après');
    expect(
      await SyncQueue.instance.hasPending(type: 'categories'),
      isTrue,
    );
  });

  test('updateCategory recreates the remote entity when the update returns null',
      () async {
    supabase.returnNullOnUpdate = true;
    final category = Fixtures.category(id: 'c1', accountId: 'a1', name: 'Recréé');

    final updated = await service.updateCategory(category);

    await SyncManager.instance.flush();
    await SyncManager.instance.waitForIdle();

    expect(updated.name, 'Recréé');
    expect(supabase.createCalls, greaterThan(0));
    expect(supabase.server.any((c) => c.id == 'c1'), isTrue);
  });

  test('deleteCategory removes from the store and enqueues a delete', () async {
    final category = Fixtures.category(id: 'c1', accountId: 'a1', name: 'Suppr');
    CategoriesStore.instance.addCategory(category);

    final deleted = await service.deleteCategory('c1');

    expect(deleted, isTrue);
    expect(service.getCategoriesForAccount('a1'), isEmpty);
    expect(
      await SyncQueue.instance.hasPending(type: 'categories'),
      isTrue,
    );
  });

  test('getCategoryById hydrates a missing icon from the catalogue', () async {
    final iconCode = '0x${groceryIcon.iconCode.toRadixString(16)}';
    CategoriesStore.instance.addCategory(Category(
      id: 'c1',
      accountId: 'a1',
      name: 'Courses',
      iconCode: iconCode,
    ));
    CategoriesStore.instance.setAvailableIcons([groceryIcon]);

    final found = service.getCategoryById('c1');

    expect(found!.icon?.iconName, 'groceries');
  });

  test('invalidateCache clears categories and icons from the store', () async {
    CategoriesStore.instance.setCategoriesForAccount('a1', [
      Fixtures.category(id: 'c1', accountId: 'a1'),
    ]);
    CategoriesStore.instance.setAvailableIcons([groceryIcon]);

    service.invalidateCache();

    expect(service.getCategoriesForAccount('a1'), isEmpty);
    expect(CategoriesStore.instance.iconsLoaded, isFalse);
  });
}
