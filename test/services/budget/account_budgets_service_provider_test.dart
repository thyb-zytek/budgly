import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes the AccountBudgetsService singleton', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(accountBudgetsServiceProvider),
      same(AccountBudgetsService.instance),
    );
  });

  test('can be overridden with a fake in tests', () {
    final fake = AccountBudgetsService();
    final container = ProviderContainer(
      overrides: [accountBudgetsServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(accountBudgetsServiceProvider), same(fake));
  });
}
