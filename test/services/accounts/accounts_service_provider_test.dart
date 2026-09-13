import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes the AccountsService singleton', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(accountsServiceProvider), same(AccountsService.instance));
  });

  test('can be overridden with a fake in tests', () {
    final fake = AccountsService();
    final container = ProviderContainer(
      overrides: [accountsServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(accountsServiceProvider), same(fake));
  });
}
