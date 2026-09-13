import 'package:budgly/src/services/categories/category_icons_service.dart';
import 'package:budgly/src/services/categories/category_icons_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes the CategoryIconsService singleton', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(categoryIconsServiceProvider),
      same(CategoryIconsService.instance),
    );
  });

  test('can be overridden with a fake in tests', () {
    final fake = CategoryIconsService();
    final container = ProviderContainer(
      overrides: [categoryIconsServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(categoryIconsServiceProvider), same(fake));
  });
}
