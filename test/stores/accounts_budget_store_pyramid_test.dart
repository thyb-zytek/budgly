import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/stores/accounts_budget.dart';
import 'package:flutter_test/flutter_test.dart';

AccountBudget budget(String accountId, int year, int month, double revenue) =>
    AccountBudget(
      accountId: accountId,
      year: year,
      month: month,
      revenue: revenue,
    );

void main() {
  late AccountBudgetsStore store;

  setUp(() {
    store = AccountBudgetsStore.instance;
    store.clearAll();
  });

  tearDown(() => store.clearAll());

  test('set does not notify when only the object identity changes', () {
    store.set('a1_2026_8', budget('a1', 2026, 8, 100));
    var notifications = 0;
    store.addListener(() => notifications++);

    store.set('a1_2026_8', budget('a1', 2026, 8, 100));

    expect(notifications, 0);
  });

  test('set notifies when revenue changes', () {
    store.set('a1_2026_8', budget('a1', 2026, 8, 100));
    var notifications = 0;
    store.addListener(() => notifications++);

    store.set('a1_2026_8', budget('a1', 2026, 8, 200));

    expect(notifications, 1);
    expect(store.get('a1_2026_8')?.revenue, 200);
  });

  test('getBudgetsForAccount ignores another account and null entries', () {
    store.set('a1_2026_8', budget('a1', 2026, 8, 100));
    store.set('a2_2026_8', budget('a2', 2026, 8, 200));
    store.set('a1_2026_9', null);

    final budgets = store.getBudgetsForAccount('a1');

    expect(budgets, hasLength(1));
    expect(budgets.single.revenue, 100);
  });

  test('clearByAccountId removes only that account', () {
    store.set('a1_2026_8', budget('a1', 2026, 8, 100));
    store.set('a2_2026_8', budget('a2', 2026, 8, 200));

    store.clearByAccountId('a1');

    expect(store.hasLoaded('a1_2026_8'), isFalse);
    expect(store.get('a1_2026_8'), isNull);
    expect(store.get('a2_2026_8')?.revenue, 200);
  });

  test('clear is a no-op for an unknown key', () {
    var notifications = 0;
    store.addListener(() => notifications++);

    store.clear('missing');

    expect(notifications, 0);
  });
}
