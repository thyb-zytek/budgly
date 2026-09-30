import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firestore-wiring coverage for `AccountBudgetFirestore` (docs/AUDIT_PLAN.md:
/// this class was flagged as having no dependency injection, which is why it
/// had no coverage of its own — `providers/firestore/accounts_budget.dart` was
/// at 15.1% after the audit's other fixes). The constructor now accepts an
/// injected `FirebaseFirestore`/`FirebaseAuth`, mirroring `ExpenseFirestore`,
/// which is what makes this file possible.
///
/// `firstRevenueBefore`'s own filtering logic is already covered by
/// `test/services/budget/most_recent_revenue_test.dart` and
/// `test/unit/revenue_inheritance_test.dart`; this file focuses on the
/// Firestore query/write wiring around it instead of repeating that.
void main() {
  const uid = 'user-1';
  const accountId = 'account-1';

  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AccountBudgetFirestore provider;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid));
    provider = AccountBudgetFirestore(firestore: firestore, auth: auth);
  });

  Future<void> seed(AccountBudget budget) => firestore
      .collection('users')
      .doc(uid)
      .collection('account_budgets')
      .doc(budget.id)
      .set(budget.toMap());

  AccountBudget budget({
    String? id,
    String account = accountId,
    int year = 2026,
    int month = 3,
    double revenue = 1000,
  }) => AccountBudget(
    id: id ?? '${account}_${year}_$month',
    accountId: account,
    year: year,
    month: month,
    revenue: revenue,
  );

  group('get', () {
    test('returns null for a month with no budget document', () async {
      expect(await provider.get(accountId, 2026, 3), isNull);
    });

    test('returns the budget for an existing document', () async {
      await seed(budget(revenue: 1500));

      final result = await provider.get(accountId, 2026, 3);
      expect(result?.revenue, 1500);
      expect(result?.accountId, accountId);
    });

    test('throws when no user is signed in', () async {
      final signedOut = AccountBudgetFirestore(
        firestore: firestore,
        auth: MockFirebaseAuth(signedIn: false),
      );
      await expectLater(signedOut.get(accountId, 2026, 3), throwsStateError);
    });
  });

  group('setRevenue', () {
    test('creates the document and returns it with a resolved id', () async {
      final result = await provider.setRevenue(accountId, 2026, 3, 2000);

      expect(result.id, 'account-1_2026_3');
      expect((await provider.get(accountId, 2026, 3))?.revenue, 2000);
    });

    test(
      'overwrites only the targeted month (merge, not replace-all)',
      () async {
        await provider.setRevenue(accountId, 2026, 3, 1000);
        await provider.setRevenue(accountId, 2026, 4, 1200);

        await provider.setRevenue(accountId, 2026, 3, 2000);

        expect((await provider.get(accountId, 2026, 3))?.revenue, 2000);
        expect((await provider.get(accountId, 2026, 4))?.revenue, 1200);
      },
    );
  });

  group('getMostRecentWithRevenue', () {
    test("queries only this account's own documents", () async {
      await seed(budget(year: 2026, month: 1, revenue: 500));
      await seed(
        budget(
          account: 'account-2',
          id: 'other',
          year: 2026,
          month: 2,
          revenue: 900,
        ),
      );

      final result = await provider.getMostRecentWithRevenue(
        accountId,
        before: const Period(year: 2026, month: 3),
      );

      expect(result?.accountId, accountId);
      expect(result?.revenue, 500);
    });
  });

  group('deleteByAccountId', () {
    test(
      'removes every budget document for the account, leaving others untouched',
      () async {
        await seed(budget(year: 2026, month: 1));
        await seed(budget(year: 2026, month: 2));
        await seed(
          budget(account: 'account-2', id: 'other', year: 2026, month: 1),
        );

        await provider.deleteByAccountId(accountId);

        final remaining = await firestore
            .collection('users')
            .doc(uid)
            .collection('account_budgets')
            .get();
        expect(remaining.docs.map((d) => d.id), ['other']);
      },
    );

    test('is a no-op, not an error, when the account has no budgets', () async {
      await expectLater(provider.deleteByAccountId('no-budgets'), completes);
    });

    test(
      'awaitAck: false still deletes; it only changes whether the call waits',
      () async {
        await seed(budget(year: 2026, month: 1));

        await provider.deleteByAccountId(accountId, awaitAck: false);
        // The fake commits in-memory synchronously either way; what matters for
        // this contract is that the caller is never left waiting on a Future
        // that only resolves on a real server acknowledgement.
        await Future<void>.delayed(Duration.zero);

        final remaining = await firestore
            .collection('users')
            .doc(uid)
            .collection('account_budgets')
            .get();
        expect(remaining.docs, isEmpty);
      },
    );

    test(
      'source: Source.server is what the durable cleanup relies on to see uncached documents',
      () async {
        await seed(budget(year: 2026, month: 1));

        await provider.deleteByAccountId(accountId, source: Source.server);

        final remaining = await firestore
            .collection('users')
            .doc(uid)
            .collection('account_budgets')
            .get();
        expect(remaining.docs, isEmpty);
      },
    );
  });
}
