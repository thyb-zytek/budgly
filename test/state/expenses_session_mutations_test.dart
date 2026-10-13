import 'dart:async';

import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// ExpensesSession is the application's source of truth for expenses. These
/// tests pin its mutation wrappers and the guards that keep stale work out of
/// it: a result is applied only if the session it belongs to is still current
/// (sign-out, account switch) and no newer local change happened meanwhile.
class _FakeExpensesService extends ExpensesService {
  _FakeExpensesService() : super(analytics: AnalyticsService());

  List<Expense> remote = [];
  bool deleteResult = true;
  int invalidations = 0;
  Completer<void>? gate;
  Completer<List<Expense>>? deferredList;

  Future<void> _maybeWait() async {
    final pending = gate;
    if (pending != null) await pending.future;
  }

  @override
  Future<Expense> createExpense(Expense expense) async {
    await _maybeWait();
    return expense;
  }

  @override
  Future<Expense> updateExpense(Expense expense, {Expense? previous}) async {
    await _maybeWait();
    return expense;
  }

  @override
  Future<bool> deleteExpense(String expenseId, String accountId) async {
    await _maybeWait();
    return deleteResult;
  }

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async {
    final deferred = deferredList;
    if (deferred != null) return deferred.future;
    return remote.where((e) => e.accountId == accountId).toList();
  }

  @override
  void invalidateCache() => invalidations++;
}

Expense _expense(
  String id,
  String accountId, {
  double amount = 10,
  int day = 1,
}) => Expense(
  id: id,
  accountId: accountId,
  categoryId: 'c1',
  name: id,
  amount: amount,
  debitDate: DateTime(2026, 8, day),
);

void main() {
  late _FakeExpensesService service;
  late ProviderContainer container;
  late ExpensesSession session;

  List<String> ids(String accountId) => [
    for (final e
        in container
                .read(expensesSessionProvider)
                .expensesByAccount[accountId] ??
            const <Expense>[])
      e.id!,
  ];

  setUp(() {
    service = _FakeExpensesService();
    container = ProviderContainer(
      overrides: [expensesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    session = container.read(expensesSessionProvider.notifier);
  });

  group('update', () {
    test('upserts the returned expense into the session', () async {
      service.remote = [_expense('e1', 'a1', amount: 10)];
      await session.loadAccount('a1');

      final updated = await session.update(
        _expense('e1', 'a1', amount: 99),
        previous: _expense('e1', 'a1', amount: 10),
      );

      expect(updated.amount, 99);
      expect(session.getExpenseById('e1')!.amount, 99);
      expect(ids('a1'), ['e1']);
    });

    test(
      'an update completing after the session was cleared is not applied',
      () async {
        service.remote = [_expense('e1', 'a1')];
        await session.loadAccount('a1');
        service.gate = Completer<void>();

        final pending = session.update(_expense('e1', 'a1', amount: 99));
        session.clear(); // sign-out while the write is in flight
        service.gate!.complete();
        await pending;

        expect(
          container.read(expensesSessionProvider).expensesByAccount,
          isEmpty,
        );
      },
    );

    test('a load started before the update cannot overwrite it', () async {
      service.remote = [_expense('e1', 'a1', amount: 10)];
      service.deferredList = Completer<List<Expense>>();
      final staleLoad = session.loadAccount('a1');

      await session.update(_expense('e1', 'a1', amount: 99));
      service.deferredList!.complete([_expense('e1', 'a1', amount: 10)]);
      await staleLoad;

      expect(session.getExpenseById('e1')!.amount, 99);
    });
  });

  group('create', () {
    test('adds the created expense, newest date first', () async {
      service.remote = [_expense('e1', 'a1', day: 1)];
      await session.loadAccount('a1');

      await session.create(_expense('e2', 'a1', day: 20));

      expect(ids('a1'), ['e2', 'e1']);
    });

    test(
      'a creation completing after the session was cleared is not applied',
      () async {
        service.gate = Completer<void>();

        final pending = session.create(_expense('e1', 'a1'));
        session.clear();
        service.gate!.complete();
        await pending;

        expect(
          container.read(expensesSessionProvider).expensesByAccount,
          isEmpty,
        );
      },
    );
  });

  group('delete', () {
    test('removes the expense once the service confirms', () async {
      service.remote = [_expense('e1', 'a1'), _expense('e2', 'a1', day: 2)];
      await session.loadAccount('a1');

      final deleted = await session.delete('e1', 'a1');

      expect(deleted, isTrue);
      expect(ids('a1'), ['e2']);
    });

    test('keeps the expense when the service reports failure', () async {
      service.remote = [_expense('e1', 'a1')];
      await session.loadAccount('a1');
      service.deleteResult = false;

      final deleted = await session.delete('e1', 'a1');

      expect(deleted, isFalse);
      expect(ids('a1'), ['e1']);
    });

    test('only touches the given account', () async {
      service.remote = [_expense('e1', 'a1'), _expense('e1', 'a2')];
      await session.loadAccount('a1');
      await session.loadAccount('a2');

      await session.delete('e1', 'a1');

      expect(ids('a1'), isEmpty);
      expect(ids('a2'), ['e1']);
    });

    test(
      'a delete completing after the session was cleared is not applied',
      () async {
        service.remote = [_expense('e1', 'a1')];
        await session.loadAccount('a1');
        service.gate = Completer<void>();

        final pending = session.delete('e1', 'a1');
        session.clear();
        service.gate!.complete();
        await pending;

        expect(
          container.read(expensesSessionProvider).expensesByAccount,
          isEmpty,
        );
      },
    );
  });

  group('local changes and clearing', () {
    test(
      'updateLocal and removeLocal change the session without a service call',
      () async {
        service.remote = [_expense('e1', 'a1')];
        await session.loadAccount('a1');

        session.updateLocal(_expense('e2', 'a1', day: 5));
        expect(ids('a1'), ['e2', 'e1']);

        session.removeLocal('e1', 'a1');
        expect(ids('a1'), ['e2']);
      },
    );

    test(
      'a local change invalidates a load that was already in flight',
      () async {
        service.remote = [_expense('e1', 'a1')];
        service.deferredList = Completer<List<Expense>>();
        final staleLoad = session.loadAccount('a1');

        session.removeLocal('e1', 'a1');
        service.deferredList!.complete([_expense('e1', 'a1')]);
        await staleLoad;

        expect(ids('a1'), isEmpty);
      },
    );

    test(
      'clearAccount forgets one account and drops the service cache',
      () async {
        service.remote = [_expense('e1', 'a1'), _expense('e2', 'a2')];
        await session.loadAccount('a1');
        await session.loadAccount('a2');

        session.clearAccount('a1');

        final state = container.read(expensesSessionProvider);
        expect(state.expensesByAccount.keys, ['a2']);
        expect(state.loadedAccounts, {'a2'});
        expect(service.invalidations, 1);
      },
    );

    test('clear forgets everything and drops the service cache', () async {
      service.remote = [_expense('e1', 'a1'), _expense('e2', 'a2')];
      await session.loadAccount('a1');
      await session.loadAccount('a2');

      session.clear();

      final state = container.read(expensesSessionProvider);
      expect(state.expensesByAccount, isEmpty);
      expect(state.loadedAccounts, isEmpty);
      expect(service.invalidations, 1);
    });

    test(
      'a load that started before clear does not repopulate the session',
      () async {
        service.remote = [_expense('e1', 'a1')];
        service.deferredList = Completer<List<Expense>>();
        final staleLoad = session.loadAccount('a1');

        session.clear();
        service.deferredList!.complete([_expense('e1', 'a1')]);
        await staleLoad;

        expect(
          container.read(expensesSessionProvider).expensesByAccount,
          isEmpty,
        );
      },
    );
  });
}
