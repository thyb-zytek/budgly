import 'package:budgly/src/stores/accounts_budget.dart';
import 'package:budgly/src/stores/accounts_budget_provider.dart';
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

  test('initial state mirrors AccountBudgetsStore', () {
    final state = container.read(accountBudgetsSessionProvider);
    expect(state.budgets, isEmpty);
    expect(state.loadedKeys, isEmpty);
  });

  test('reflects set() made outside Riverpod', () {
    container.read(accountBudgetsSessionProvider);

    var notifications = 0;
    container.listen(accountBudgetsSessionProvider, (previous, next) => notifications++);

    final period = Fixtures.period(2026, 3);
    final budget = Fixtures.budget(accountId: 'a1', period: period, revenue: 2500);
    AccountBudgetsStore.instance.set('a1_2026_3', budget);

    final state = container.read(accountBudgetsSessionProvider);
    expect(state.budgets['a1_2026_3']?.revenue, 2500);
    expect(state.loadedKeys, contains('a1_2026_3'));
    expect(notifications, greaterThanOrEqualTo(1));
  });

  test('reflects clear() and clearByAccountId()', () {
    container.read(accountBudgetsSessionProvider);
    final period = Fixtures.period(2026, 3);
    AccountBudgetsStore.instance.set(
      'a1_2026_3',
      Fixtures.budget(accountId: 'a1', period: period),
    );
    AccountBudgetsStore.instance.set(
      'a1_2026_4',
      Fixtures.budget(accountId: 'a1', period: Fixtures.period(2026, 4)),
    );

    AccountBudgetsStore.instance.clear('a1_2026_3');
    expect(container.read(accountBudgetsSessionProvider).budgets.containsKey('a1_2026_3'), isFalse);
    expect(container.read(accountBudgetsSessionProvider).budgets.containsKey('a1_2026_4'), isTrue);

    AccountBudgetsStore.instance.clearByAccountId('a1');
    expect(container.read(accountBudgetsSessionProvider).budgets, isEmpty);
  });

  test('an unrelated key is unaffected by another key changing', () {
    container.read(accountBudgetsSessionProvider);
    AccountBudgetsStore.instance.set(
      'a1_2026_3',
      Fixtures.budget(accountId: 'a1', period: Fixtures.period(2026, 3)),
    );
    AccountBudgetsStore.instance.set(
      'a2_2026_3',
      Fixtures.budget(accountId: 'a2', period: Fixtures.period(2026, 3)),
    );

    final before = container.read(
      accountBudgetsSessionProvider.select((s) => s.budgets['a1_2026_3']),
    );

    AccountBudgetsStore.instance.set(
      'a2_2026_3',
      Fixtures.budget(accountId: 'a2', period: Fixtures.period(2026, 3), revenue: 9999),
    );

    final after = container.read(
      accountBudgetsSessionProvider.select((s) => s.budgets['a1_2026_3']),
    );
    expect(identical(before, after), isTrue);
  });

  test('disposing the container detaches the store listener without error', () {
    final localContainer = ProviderContainer();
    localContainer.read(accountBudgetsSessionProvider);
    localContainer.dispose();

    expect(
      () => AccountBudgetsStore.instance.set(
        'a1_2026_3',
        Fixtures.budget(accountId: 'a1', period: Fixtures.period(2026, 3)),
      ),
      returnsNormally,
    );
  });
}
