import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/expenses/expense_period_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';

void main() {
  late ExpensePeriodCache cache;

  setUp(() => cache = ExpensePeriodCache());

  test('builds stable keys with and without a category', () {
    const period = Period(year: 2026, month: 9);
    expect(cache.key('a1', period, null), 'a1|2026-09|*');
    expect(cache.key('a1', period, 'c1'), 'a1|2026-09|c1');
  });

  test('put copies the list and cached returns the stored snapshot', () {
    const period = Period(year: 2026, month: 9);
    final expenses = [Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1')];
    final key = cache.key('a1', period, null);

    cache.put(key, expenses);
    expenses.clear();

    expect(cache.cached(key), hasLength(1));
  });

  test('mergeServer preserves pending optimistic creates', () {
    const period = Period(year: 2026, month: 9);
    final key = cache.key('a1', period, null);
    final local = Fixtures.expense(id: 'offline', accountId: 'a1', categoryId: 'c1', debitDate: DateTime(2026, 9, 20));
    final server = Fixtures.expense(id: 'server', accountId: 'a1', categoryId: 'c1', debitDate: DateTime(2026, 9, 10));

    cache.put(key, [local]);
    cache.addOptimistic('offline');
    cache.markPending('offline', local);

    final merged = cache.mergeServer(key, [server]);

    expect(merged.map((e) => e.id), ['offline', 'server']);
  });

  test('mergeServer keeps pending mutations authoritative over stale snapshots', () {
    const period = Period(year: 2026, month: 9);
    final key = cache.key('a1', period, null);
    final deleted = Fixtures.expense(id: 'deleted', accountId: 'a1', categoryId: 'c1');
    final acknowledged = Fixtures.expense(id: 'ack', accountId: 'a1', categoryId: 'c1');

    cache.put(key, [deleted, acknowledged]);
    cache.markPendingDelete('deleted');
    cache.markPending('ack', acknowledged);

    final merged = cache.mergeServer(key, [deleted, acknowledged]);

    expect(merged.map((e) => e.id), ['ack']);

    // A server snapshot containing the old value must not clear the pending
    // protection. The shield is only released once the server confirms the
    // expense in a refresh (ExpensePeriodCache.releaseConfirmed), not as a
    // side effect of the read path.
    final stale = acknowledged.copyWith(amount: acknowledged.amount + 50);
    cache.markPending('ack', acknowledged);
    final staleMerged = cache.mergeServer(key, [stale]);
    expect(staleMerged.single.amount, acknowledged.amount);

    cache.clearPending('ack');
    final authoritative = cache.mergeServer(key, [stale]);
    expect(authoritative.single.amount, stale.amount);
  });

  test('optimistic update moves an expense between loaded periods', () {
    const oldPeriod = Period(year: 2026, month: 9);
    const newPeriod = Period(year: 2026, month: 10);
    final oldKey = cache.key('a1', oldPeriod, null);
    final newKey = cache.key('a1', newPeriod, null);
    final oldExpense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1', debitDate: DateTime(2026, 9, 20));
    final newExpense = oldExpense.copyWith(debitDate: DateTime(2026, 10, 1));

    cache.put(oldKey, [oldExpense]);
    cache.put(newKey, []);
    cache.optimisticUpdateExpense(oldExpense, newExpense);

    expect(cache.cached(oldKey), isEmpty);
    expect(cache.cached(newKey), [newExpense]);
  });
}
