import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CategoriesStore store;

  setUp(() {
    store = CategoriesStore.instance;
    store.clearAll();
  });

  Category buildCategory({
    String id = 'cat-1',
    String accountId = 'account-1',
    String name = 'Food',
  }) {
    return Category(id: id, accountId: accountId, name: name);
  }

  group('CategoriesStore.setCategoriesForAccount', () {
    test('stores categories for account', () {
      store.setCategoriesForAccount('acc-1', [buildCategory()]);
      expect(store.getCategoriesForAccount('acc-1'), hasLength(1));
    });

    test('does not notify when categories are unchanged', () {
      store.setCategoriesForAccount('acc-1', [buildCategory()]);
      var notified = false;
      store.addListener(() => notified = true);
      store.setCategoriesForAccount('acc-1', [buildCategory()]);
      expect(notified, isFalse);
    });

    test('marks account as loaded', () {
      store.setCategoriesForAccount('acc-1', []);
      expect(store.hasLoadedAccount('acc-1'), isTrue);
    });

    test('returns unmodifiable list', () {
      store.setCategoriesForAccount('acc-1', [buildCategory()]);
      final list = store.getCategoriesForAccount('acc-1');
      expect(() => list.add(buildCategory(id: 'c2')), throwsUnsupportedError);
    });
  });

  group('CategoriesStore.getCategoryById', () {
    test('finds category across all accounts', () {
      store.setCategoriesForAccount('acc-1', [buildCategory(id: 'c1')]);
      store.setCategoriesForAccount('acc-2', [buildCategory(id: 'c2', accountId: 'acc-2')]);

      expect(store.getCategoryById('c2')?.accountId, 'acc-2');
    });

    test('returns null for nonexistent id', () {
      expect(store.getCategoryById('nonexistent'), isNull);
    });
  });

  group('CategoriesStore.addCategory', () {
    test('adds to correct account', () {
      store.addCategory(buildCategory(id: 'c1', accountId: 'acc-1'));
      store.addCategory(buildCategory(id: 'c2', accountId: 'acc-2'));

      expect(store.getCategoriesForAccount('acc-1'), hasLength(1));
      expect(store.getCategoriesForAccount('acc-2'), hasLength(1));
    });

    test('creates account list if not exists', () {
      store.addCategory(buildCategory(id: 'c1', accountId: 'new-acc'));
      expect(store.getCategoriesForAccount('new-acc'), hasLength(1));
    });
  });

  group('CategoriesStore.updateCategory', () {
    test('updates existing category', () {
      store.setCategoriesForAccount('acc-1', [buildCategory(id: 'c1', name: 'Old')]);
      store.updateCategory(buildCategory(id: 'c1', name: 'New', accountId: 'acc-1'));

      final cats = store.getCategoriesForAccount('acc-1');
      expect(cats.first.name, 'New');
    });

    test('no-op when category id not found', () {
      store.setCategoriesForAccount('acc-1', [buildCategory(id: 'c1')]);
      store.updateCategory(buildCategory(id: 'c999', name: 'X', accountId: 'acc-1'));

      expect(store.getCategoriesForAccount('acc-1'), hasLength(1));
    });
  });

  group('CategoriesStore.removeCategory', () {
    test('removes category by id', () {
      store.setCategoriesForAccount('acc-1', [
        buildCategory(id: 'c1'),
        buildCategory(id: 'c2'),
      ]);

      store.removeCategory('c1');
      expect(store.getCategoriesForAccount('acc-1'), hasLength(1));
    });

    test('notifies when category is found and removed', () {
      store.setCategoriesForAccount('acc-1', [buildCategory(id: 'c1')]);
      var notified = false;
      store.addListener(() => notified = true);
      store.removeCategory('c1');
      expect(notified, isTrue);
    });
  });

  group('CategoriesStore.clearAccountCache', () {
    test('removes categories for account', () {
      store.setCategoriesForAccount('acc-1', [buildCategory()]);
      store.clearAccountCache('acc-1');

      expect(store.hasLoadedAccount('acc-1'), isFalse);
      expect(store.getCategoriesForAccount('acc-1'), isEmpty);
    });
  });

  group('CategoriesStore.setAvailableIcons', () {
    test('stores icons and marks iconsLoaded', () {
      const icon = CategoryIcon(
        iconName: 'test',
        iconCode: 0xe001,
        iconPack: 'MaterialIcons',
        labels: {'en': 'Test'},
      );

      store.setAvailableIcons([icon]);
      expect(store.availableIcons, hasLength(1));
      expect(store.iconsLoaded, isTrue);
    });

    test('empty list does not set iconsLoaded', () {
      store.setAvailableIcons([]);
      expect(store.iconsLoaded, isFalse);
    });
  });

  group('CategoriesStore.clearAll', () {
    test('clears everything', () {
      store.setCategoriesForAccount('acc-1', [buildCategory()]);
      store.clearAll();

      expect(store.getCategoriesForAccount('acc-1'), isEmpty);
      expect(store.availableIcons, isEmpty);
      expect(store.iconsLoaded, isFalse);
    });
  });
}
