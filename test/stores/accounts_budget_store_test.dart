import 'package:budgly/src/stores/accounts_budget.dart';
import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AccountBudgetsStore store;

  setUp(() {
    store = AccountBudgetsStore.instance;
    store.clearAll();
  });

  AccountBudget buildBudget({
    String accountId = 'acc-1',
    int year = 2026,
    int month = 6,
    double revenue = 2000,
  }) {
    return AccountBudget(
      accountId: accountId,
      year: year,
      month: month,
      revenue: revenue,
    );
  }

  group('AccountBudgetsStore basic operations', () {
    test('set and get budget', () {
      final key = 'acc-1_2026_6';
      store.set(key, buildBudget());
      expect(store.get(key), isNotNull);
      expect(store.get(key)!.revenue, 2000);
    });

    test('hasLoaded returns true after set', () {
      final key = 'acc-1_2026_6';
      store.set(key, buildBudget());
      expect(store.hasLoaded(key), isTrue);
    });

    test('hasLoaded returns false for unknown key', () {
      expect(store.hasLoaded('unknown'), isFalse);
    });

    test('get returns null for unknown key', () {
      expect(store.get('unknown'), isNull);
    });

    test('clear removes specific key', () {
      final key = 'acc-1_2026_6';
      store.set(key, buildBudget());
      store.clear(key);
      expect(store.hasLoaded(key), isFalse);
      expect(store.get(key), isNull);
    });

    test('clearAll removes everything', () {
      store.set('a', buildBudget());
      store.set('b', buildBudget(accountId: 'acc-2'));
      store.clearAll();
      expect(store.hasLoaded('a'), isFalse);
      expect(store.hasLoaded('b'), isFalse);
    });
  });

  group('AccountBudgetsStore.clearByAccountId', () {
    test('removes all budgets for an account', () {
      store.set('acc-1_2026_1', buildBudget(month: 1));
      store.set('acc-1_2026_2', buildBudget(month: 2));
      store.set('acc-2_2026_1', buildBudget(accountId: 'acc-2', month: 1));

      store.clearByAccountId('acc-1');

      expect(store.hasLoaded('acc-1_2026_1'), isFalse);
      expect(store.hasLoaded('acc-1_2026_2'), isFalse);
      expect(store.hasLoaded('acc-2_2026_1'), isTrue);
    });

    test('no-op when no keys match', () {
      store.set('acc-1_2026_1', buildBudget());
      store.clearByAccountId('acc-999');
      expect(store.hasLoaded('acc-1_2026_1'), isTrue);
    });
  });

  group('AccountBudgetsStore null budget', () {
    test('set with null budget and get it', () {
      final key = 'acc-1_2026_6';
      store.set(key, null);
      expect(store.hasLoaded(key), isTrue);
      expect(store.get(key), isNull);
    });
  });

  group('AccountBudgetsStore listeners', () {
    test('notifies on set', () {
      var notified = false;
      store.addListener(() => notified = true);
      store.set('key', buildBudget());
      expect(notified, isTrue);
    });

    test('does not notify when setting the same revenue', () {
      store.set('key', buildBudget(revenue: 2000));
      var notified = false;
      store.addListener(() => notified = true);
      store.set('key', buildBudget(revenue: 2000));
      expect(notified, isFalse);
    });

    test('notifies on clear', () {
      store.set('key', buildBudget());
      var notified = false;
      store.addListener(() => notified = true);
      store.clear('key');
      expect(notified, isTrue);
    });

    test('notifies on clearAll', () {
      store.set('key', buildBudget());
      var notified = false;
      store.addListener(() => notified = true);
      store.clearAll();
      expect(notified, isTrue);
    });

    test('notifies on clearByAccountId', () {
      store.set('acc-1_2026_6', buildBudget());
      var notified = false;
      store.addListener(() => notified = true);
      store.clearByAccountId('acc-1');
      expect(notified, isTrue);
    });
  });
}

// Notification behavior is intentionally covered here because stores are the
// main boundary that controls how far a local data mutation propagates into
// the widget tree.
