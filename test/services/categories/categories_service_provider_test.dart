import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes the CategoriesService singleton', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(categoriesServiceProvider), same(CategoriesService.instance));
  });

  test('can be overridden with a fake in tests', () {
    final fake = CategoriesService();
    final container = ProviderContainer(
      overrides: [categoriesServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(categoriesServiceProvider), same(fake));
  });
}
