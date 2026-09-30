import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers.dart';

void main() {
  test('creates the CategoriesService through Riverpod', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(categoriesServiceProvider);
    expect(service, isA<CategoriesService>());
  });

  test('can be overridden with a fake in tests', () {
    final fake = CategoriesService(
      analytics: AnalyticsService(),
      syncManager: testSyncManager,
      syncQueue: testSyncQueue,
    );
    final container = ProviderContainer(
      overrides: [categoriesServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(categoriesServiceProvider), same(fake));
  });
}
