import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/stores/categories_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';
import '../helpers/fake_stores.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    clearAllTestStores();
    Fixtures.resetSeq();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(clearAllTestStores);

  test('initial state mirrors CategoriesStore', () {
    final state = container.read(categoriesSessionProvider);
    expect(state.categoriesByAccount, isEmpty);
    expect(state.availableIcons, isEmpty);
    expect(state.iconsLoaded, isFalse);
  });

  test('reflects setCategoriesForAccount made outside Riverpod', () {
    container.read(categoriesSessionProvider);

    var notifications = 0;
    container.listen(categoriesSessionProvider, (previous, next) => notifications++);

    CategoriesStore.instance.setCategoriesForAccount('a1', [
      Fixtures.category(id: 'c1', accountId: 'a1'),
    ]);

    final state = container.read(categoriesSessionProvider);
    expect(state.categoriesByAccount['a1']!.single.id, 'c1');
    expect(notifications, greaterThanOrEqualTo(1));
  });

  test('reflects addCategory / updateCategory / removeCategory', () {
    container.read(categoriesSessionProvider);
    CategoriesStore.instance.setCategoriesForAccount('a1', [
      Fixtures.category(id: 'c1', accountId: 'a1', name: 'Courses'),
    ]);

    CategoriesStore.instance.addCategory(
      Fixtures.category(id: 'c2', accountId: 'a1', name: 'Transport'),
    );
    expect(container.read(categoriesSessionProvider).categoriesByAccount['a1']!.length, 2);

    CategoriesStore.instance.updateCategory(
      Fixtures.category(id: 'c1', accountId: 'a1', name: 'Alimentation'),
    );
    expect(
      container
          .read(categoriesSessionProvider)
          .categoriesByAccount['a1']!
          .firstWhere((c) => c.id == 'c1')
          .name,
      'Alimentation',
    );

    CategoriesStore.instance.removeCategory('c2');
    expect(container.read(categoriesSessionProvider).categoriesByAccount['a1']!.length, 1);
  });

  test('reflects setAvailableIcons', () {
    container.read(categoriesSessionProvider);
    CategoriesStore.instance.setAvailableIcons([Fixtures.categoryIcon()]);

    final state = container.read(categoriesSessionProvider);
    expect(state.availableIcons, hasLength(1));
    expect(state.iconsLoaded, isTrue);
  });

  test('an unrelated account is unaffected by another account changing', () {
    container.read(categoriesSessionProvider);
    CategoriesStore.instance.setCategoriesForAccount('a1', [
      Fixtures.category(id: 'c1', accountId: 'a1'),
    ]);
    CategoriesStore.instance.setCategoriesForAccount('a2', [
      Fixtures.category(id: 'c2', accountId: 'a2'),
    ]);

    final before = container.read(
      categoriesSessionProvider.select((s) => s.categoriesByAccount['a1']),
    );

    CategoriesStore.instance.addCategory(
      Fixtures.category(id: 'c3', accountId: 'a2', name: 'Loisirs'),
    );

    final after = container.read(
      categoriesSessionProvider.select((s) => s.categoriesByAccount['a1']),
    );
    expect(identical(before, after), isTrue);
  });

  test('disposing the container detaches the store listener without error', () {
    final localContainer = ProviderContainer();
    localContainer.read(categoriesSessionProvider);
    localContainer.dispose();

    expect(
      () => CategoriesStore.instance.setCategoriesForAccount('a1', []),
      returnsNormally,
    );
  });
}
