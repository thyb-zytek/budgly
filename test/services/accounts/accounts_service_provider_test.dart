import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers.dart';

void main() {
  test('creates the AccountsService through Riverpod', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(accountsServiceProvider);
    expect(service, isA<AccountsService>());
  });

  test('can be overridden with a fake in tests', () {
    final fake = AccountsService(
      analytics: AnalyticsService(),
      syncManager: testSyncManager,
      syncQueue: testSyncQueue,
    );
    final container = ProviderContainer(
      overrides: [accountsServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(accountsServiceProvider), same(fake));
  });
}
