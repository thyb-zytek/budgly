import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates AccountBudgetsService through Riverpod', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(accountBudgetsServiceProvider),
      isA<AccountBudgetsService>(),
    );
  });

  test('can be overridden with a fake in tests', () {
    final fake = AccountBudgetsService(analytics: AnalyticsService());
    final container = ProviderContainer(
      overrides: [accountBudgetsServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(accountBudgetsServiceProvider), same(fake));
  });
}
