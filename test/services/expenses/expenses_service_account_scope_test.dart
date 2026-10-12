import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Account/category scoped reads and removals of ExpensesService, over the real
/// ExpenseFirestore provider backed by an in-memory Firestore.
///
/// Ownership contract: removing or listing one account's (or category's)
/// expenses must never touch another account's documents.
class _FailingRemovalFirestore extends ExpenseFirestore {
  _FailingRemovalFirestore({super.firestore, super.auth});

  @override
  Future<void> deleteByAccountId(
    String accountId, {
    Source source = Source.serverAndCache,
    bool awaitAck = true,
  }) async => throw StateError('offline');

  @override
  Future<void> deleteByCategoryId(
    String categoryId, {
    Source source = Source.serverAndCache,
    bool awaitAck = true,
  }) async => throw StateError('offline');

  @override
  Future<List<Expense>> listByAccountBefore(
    String accountId,
    DateTime endExclusive, {
    Source source = Source.server,
  }) async => throw StateError('offline');
}

void main() {
  const uid = 'user-1';

  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late ExpenseFirestore provider;
  late ExpensesService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid));
    provider = ExpenseFirestore(firestore: firestore, auth: auth);
    service = ExpensesService(
      expenseFirestore: provider,
      analytics: AnalyticsService(),
    );
  });

  Expense expense(
    String id, {
    String account = 'a1',
    String category = 'c1',
    DateTime? debitDate,
  }) => Expense(
    id: id,
    accountId: account,
    categoryId: category,
    name: id,
    amount: 10,
    debitDate: debitDate ?? DateTime(2026, 2, 10),
  );

  Future<void> seed(List<Expense> expenses) async {
    for (final value in expenses) {
      await provider.create(value);
    }
  }

  Future<Set<String>> persistedIds() async {
    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .get();
    return {for (final doc in snapshot.docs) doc.id};
  }

  group('listExpensesForAccountBefore', () {
    test(
      'a forced refresh returns the expenses before the bound, newest first',
      () async {
        await seed([
          expense('jan', debitDate: DateTime(2026, 1, 10)),
          expense('feb', debitDate: DateTime(2026, 2, 10)),
          expense('mar', debitDate: DateTime(2026, 3, 10)),
          expense(
            'other-account',
            account: 'a2',
            debitDate: DateTime(2026, 1, 5),
          ),
        ]);

        final listed = await service.listExpensesForAccountBefore(
          'a1',
          DateTime(2026, 3, 1),
          forceRefresh: true,
        );

        expect(listed.map((e) => e.id), ['feb', 'jan']);
      },
    );

    test(
      'the bound is exclusive: an expense on the bound day is not included',
      () async {
        await seed([
          expense('before', debitDate: DateTime(2026, 2, 28)),
          expense('on-bound', debitDate: DateTime(2026, 3, 1)),
        ]);

        final listed = await service.listExpensesForAccountBefore(
          'a1',
          DateTime(2026, 3, 1),
          forceRefresh: true,
        );

        expect(listed.map((e) => e.id), ['before']);
      },
    );

    test(
      'without a forced refresh only what is already cached is answered',
      () async {
        await seed([expense('jan', debitDate: DateTime(2026, 1, 10))]);

        final listed = await service.listExpensesForAccountBefore(
          'a1',
          DateTime(2026, 3, 1),
        );

        expect(listed, isEmpty);
      },
    );

    test(
      'a failing server read falls back to the local state instead of throwing',
      () async {
        final failing = ExpensesService(
          expenseFirestore: _FailingRemovalFirestore(
            firestore: firestore,
            auth: auth,
          ),
          analytics: AnalyticsService(),
        );

        final listed = await failing.listExpensesForAccountBefore(
          'a1',
          DateTime(2026, 3, 1),
          forceRefresh: true,
        );

        expect(listed, isEmpty);
      },
    );
  });

  group('removals by account and category', () {
    setUp(() async {
      await seed([
        expense('a1-c1', account: 'a1', category: 'c1'),
        expense('a1-c2', account: 'a1', category: 'c2'),
        expense('a2-c1', account: 'a2', category: 'c1'),
      ]);
    });

    test('deleteByAccountId removes only that account', () async {
      await service.deleteByAccountId('a1');
      await pumpEventQueue();

      expect(await persistedIds(), {'a2-c1'});
    });

    test('deleteByCategoryId removes only that category', () async {
      await service.deleteByCategoryId('c1');
      await pumpEventQueue();

      expect(await persistedIds(), {'a1-c2'});
    });

    test('purgeByAccountId removes only that account', () async {
      await service.purgeByAccountId('a2');

      expect(await persistedIds(), {'a1-c1', 'a1-c2'});
    });

    test('purgeByCategoryId removes only that category', () async {
      await service.purgeByCategoryId('c2');

      expect(await persistedIds(), {'a1-c1', 'a2-c1'});
    });

    test('the immediate local removal swallows a failure, the durable purge reports it', () async {
      final failing = ExpensesService(
        expenseFirestore: _FailingRemovalFirestore(
          firestore: firestore,
          auth: auth,
        ),
        analytics: AnalyticsService(),
      );

      await failing.deleteByAccountId('a1');
      await failing.deleteByCategoryId('c1');
      await expectLater(failing.purgeByAccountId('a1'), throwsStateError);
      await expectLater(failing.purgeByCategoryId('c1'), throwsStateError);

      // Nothing was removed by the failed calls: the cleanup can be retried.
      expect(await persistedIds(), {'a1-c1', 'a1-c2', 'a2-c1'});
    });
  });
}
