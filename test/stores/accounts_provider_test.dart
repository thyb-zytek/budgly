import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/stores/accounts_provider.dart';
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

  test('initial state mirrors AccountsStore', () {
    final state = container.read(accountsSessionProvider);
    expect(state.accounts, isEmpty);
    expect(state.hasLoaded, isFalse);
  });

  test('reflects setAccounts made outside Riverpod', () {
    container.read(accountsSessionProvider); // ensure build() ran

    var notifications = 0;
    container.listen(accountsSessionProvider, (previous, next) => notifications++);

    AccountsStore.instance.setAccounts([
      Fixtures.account(id: 'a1', name: 'Compte A'),
    ]);

    final state = container.read(accountsSessionProvider);
    expect(state.accounts.single.name, 'Compte A');
    expect(state.hasLoaded, isTrue);
    expect(notifications, greaterThanOrEqualTo(1));
  });

  test('reflects addAccount / updateAccount / removeAccount', () {
    container.read(accountsSessionProvider);
    AccountsStore.instance.setAccounts([Fixtures.account(id: 'a1', name: 'A')]);

    AccountsStore.instance.addAccount(Fixtures.account(id: 'a2', name: 'B'));
    expect(container.read(accountsSessionProvider).accounts.length, 2);

    AccountsStore.instance.updateAccount(
      Fixtures.account(id: 'a1', name: 'A renamed'),
    );
    expect(
      container.read(accountsSessionProvider).accounts.firstWhere((a) => a.id == 'a1').name,
      'A renamed',
    );

    AccountsStore.instance.removeAccount('a2');
    expect(container.read(accountsSessionProvider).accounts.length, 1);
  });

  test('unrelated selection is unaffected by a change to a different account', () {
    container.read(accountsSessionProvider);
    AccountsStore.instance.setAccounts([
      Fixtures.account(id: 'a1', name: 'A'),
      Fixtures.account(id: 'a2', name: 'B'),
    ]);

    final before = container.read(
      accountsSessionProvider.select((s) => s.accounts.firstWhere((a) => a.id == 'a1')),
    );

    AccountsStore.instance.updateAccount(Fixtures.account(id: 'a2', name: 'B renamed'));

    final after = container.read(
      accountsSessionProvider.select((s) => s.accounts.firstWhere((a) => a.id == 'a1')),
    );
    expect(identical(before, after), isTrue);
  });

  test('disposing the container detaches the store listener without error', () {
    final localContainer = ProviderContainer();
    localContainer.read(accountsSessionProvider);
    localContainer.dispose();

    expect(
      () => AccountsStore.instance.setAccounts([Fixtures.account(id: 'a1')]),
      returnsNormally,
    );
  });
}
