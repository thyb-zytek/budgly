import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const uid = 'user-1';
  const accountId = 'account-1';
  const categoryId = 'category-1';
  const otherCategoryId = 'category-2';
  const period = Period(year: 2026, month: 8);

  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late ExpenseFirestore provider;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, email: 'test@budgly.app'),
    );
    provider = ExpenseFirestore(firestore: firestore, auth: auth);
  });

  Expense expense({
    String? id = 'expense-1',
    String account = accountId,
    String category = categoryId,
    String name = 'Courses',
    double amount = 42,
    DateTime? debitDate,
    DateTime? endDate,
    RecurrenceType recurrence = RecurrenceType.none,
    bool isDebited = false,
    List<String> debitedOccurrences = const [],
  }) => Expense(
    id: id,
    accountId: account,
    categoryId: category,
    name: name,
    amount: amount,
    debitDate: debitDate ?? DateTime(2026, 8, 15),
    endDate: endDate,
    recurrence: recurrence,
    isDebited: isDebited,
    debitedOccurrences: debitedOccurrences,
  );

  Future<void> seed(Expense value) async {
    await firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(value.id)
        .set(value.toCreateMap());
  }

  group('authentication', () {
    test('throws when no user is authenticated', () {
      final anonymous = ExpenseFirestore(
        firestore: firestore,
        auth: MockFirebaseAuth(signedIn: false),
      );

      expect(
        () => anonymous.listByAccountId(accountId),
        throwsStateError,
      );
    });
  });

  group('create', () {
    test('creates an expense with its explicit id', () async {
      final created = await provider.create(expense(id: 'explicit-id'));

      expect(created?.id, 'explicit-id');
      final snapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc('explicit-id')
          .get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()?['accountId'], accountId);
      expect(snapshot.data()?['amount'], 42);
      expect(snapshot.data()?['recurrence'], 'none');
    });

    test('generates and returns an id when the expense has no id', () async {
      final created = await provider.create(expense(id: null));

      expect(created?.id, isNotNull);
      expect(created!.id, isNotEmpty);
      expect(
        (await firestore
                .collection('users')
                .doc(uid)
                .collection('expenses')
                .doc(created.id)
                .get())
            .exists,
        isTrue,
      );
    });
  });

  group('update', () {
    test('updates an existing expense', () async {
      await seed(expense(id: 'expense-1', amount: 42));

      final updated = expense(
        id: 'expense-1',
        name: 'Courses modifiées',
        amount: 55.5,
        isDebited: true,
      );

      expect(await provider.update(updated), isTrue);

      final result = await firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc('expense-1')
          .get();
      expect(result.data()?['name'], 'Courses modifiées');
      expect(result.data()?['amount'], 55.5);
      expect(result.data()?['isDebited'], isTrue);
    });

    test('returns false when the expense has no id', () async {
      expect(await provider.update(expense(id: null)), isFalse);
    });

    test('returns false when the document does not exist', () async {
      expect(
        await provider.update(expense(id: 'missing')),
        isFalse,
      );
    });
  });

  group('delete', () {
    test('deletes an expense', () async {
      await seed(expense(id: 'expense-1'));

      expect(await provider.delete('expense-1'), isTrue);
      expect(
        (await firestore
                .collection('users')
                .doc(uid)
                .collection('expenses')
                .doc('expense-1')
                .get())
            .exists,
        isFalse,
      );
    });
  });

  group('splitRecurringExpense', () {
    test('updates the previous version and creates the next version atomically',
        () async {
      await seed(
        expense(
          id: 'previous',
          name: 'Ancienne version',
          amount: 50,
          recurrence: RecurrenceType.monthly,
        ),
      );

      final previous = expense(
        id: 'previous',
        name: 'Ancienne version',
        amount: 50,
        recurrence: RecurrenceType.monthly,
        endDate: DateTime(2026, 8, 31),
      );
      final next = expense(
        id: null,
        name: 'Nouvelle version',
        amount: 60,
        debitDate: DateTime(2026, 9, 1),
        recurrence: RecurrenceType.monthly,
      );

      final createdNext = await provider.splitRecurringExpense(
        previous: previous,
        next: next,
      );

      expect(createdNext?.id, isNotNull);
      expect(createdNext!.id, isNot('previous'));

      final previousSnapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc('previous')
          .get();
      expect(
        (previousSnapshot.data()?['endDate'] as Timestamp).toDate(),
        DateTime(2026, 8, 31),
      );

      final nextSnapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc(createdNext.id)
          .get();
      expect(nextSnapshot.data()?['name'], 'Nouvelle version');
      expect(nextSnapshot.data()?['amount'], 60);
    });

    test('returns null when the previous expense has no id', () async {
      final result = await provider.splitRecurringExpense(
        previous: expense(id: null),
        next: expense(id: null),
      );

      expect(result, isNull);
    });
  });

  group('listByAccountId', () {
    test('returns only the requested account, ordered by debit date', () async {
      await seed(expense(id: 'old', debitDate: DateTime(2026, 7, 1)));
      await seed(expense(id: 'new', debitDate: DateTime(2026, 8, 20)));
      await seed(
        expense(
          id: 'other-account',
          account: 'account-2',
          debitDate: DateTime(2026, 8, 25),
        ),
      );

      final result = await provider.listByAccountId(accountId);

      expect(result.map((item) => item.id), ['new', 'old']);
    });
  });

  group('listByAccountAndPeriod', () {
    test('filters one-off expenses to the requested period', () async {
      await seed(expense(id: 'in-period', debitDate: DateTime(2026, 8, 10)));
      await seed(expense(id: 'before', debitDate: DateTime(2026, 7, 31, 23, 59)));
      await seed(expense(id: 'after', debitDate: DateTime(2026, 9, 1)));

      final result = await provider.listByAccountAndPeriod(accountId, period);

      expect(result.map((item) => item.id), ['in-period']);
    });

    test('filters by category when categoryId is provided', () async {
      await seed(expense(id: 'matching', category: categoryId));
      await seed(expense(id: 'other', category: otherCategoryId));

      final result = await provider.listByAccountAndPeriod(
        accountId,
        period,
        categoryId: categoryId,
      );

      expect(result.map((item) => item.id), ['matching']);
    });

    test('keeps recurring expenses overlapping the period', () async {
      await seed(
        expense(
          id: 'active',
          debitDate: DateTime(2026, 6, 15),
          endDate: DateTime(2026, 9, 15),
          recurrence: RecurrenceType.monthly,
        ),
      );
      await seed(
        expense(
          id: 'ended-before',
          debitDate: DateTime(2026, 5, 15),
          endDate: DateTime(2026, 7, 31),
          recurrence: RecurrenceType.monthly,
        ),
      );
      await seed(
        expense(
          id: 'starts-after',
          debitDate: DateTime(2026, 9, 1),
          recurrence: RecurrenceType.monthly,
        ),
      );
      await seed(
        expense(
          id: 'open-ended',
          debitDate: DateTime(2026, 1, 1),
          recurrence: RecurrenceType.monthly,
        ),
      );

      final result = await provider.listByAccountAndPeriod(accountId, period);

      expect(result.map((item) => item.id).toSet(), {'active', 'open-ended'});
    });

    test('includes recurring expenses by default', () async {
      await seed(expense(id: 'one-off'));
      await seed(
        expense(
          id: 'recurring',
          recurrence: RecurrenceType.monthly,
        ),
      );

      final result = await provider.listByAccountAndPeriod(accountId, period);

      expect(result.map((item) => item.id).toSet(), {'one-off', 'recurring'});
    });
  });

  group('listByCategoryAndPeriodPage', () {
    test('returns one-off and active recurring expenses for the category',
        () async {
      await seed(expense(id: 'one-off', debitDate: DateTime(2026, 8, 20)));
      await seed(
        expense(
          id: 'recurring',
          debitDate: DateTime(2026, 6, 20),
          recurrence: RecurrenceType.monthly,
        ),
      );
      await seed(expense(id: 'other-category', category: otherCategoryId));

      final page = await provider.listByCategoryAndPeriodPage(
        accountId,
        categoryId,
        period,
      );

      expect(page.expenses.map((item) => item.id), ['one-off', 'recurring']);
      expect(page.hasMore, isFalse);
    });

    test('can exclude recurring expenses from the page', () async {
      await seed(expense(id: 'one-off'));
      await seed(
        expense(id: 'recurring', recurrence: RecurrenceType.monthly),
      );

      final page = await provider.listByCategoryAndPeriodPage(
        accountId,
        categoryId,
        period,
        includeRecurring: false,
      );

      expect(page.expenses.map((item) => item.id), ['one-off']);
    });

    test('paginates one-off expenses with the returned cursor', () async {
      await seed(expense(id: 'newest', debitDate: DateTime(2026, 8, 25)));
      await seed(expense(id: 'middle', debitDate: DateTime(2026, 8, 20)));
      await seed(expense(id: 'oldest', debitDate: DateTime(2026, 8, 10)));

      final first = await provider.listByCategoryAndPeriodPage(
        accountId,
        categoryId,
        period,
        limit: 1,
        includeRecurring: false,
      );
      final second = await provider.listByCategoryAndPeriodPage(
        accountId,
        categoryId,
        period,
        limit: 1,
        startAfter: first.cursor,
        includeRecurring: false,
      );

      expect(first.expenses.map((item) => item.id), ['newest']);
      expect(first.hasMore, isTrue);
      expect(second.expenses.map((item) => item.id), ['middle']);
      expect(second.hasMore, isTrue);
    });
  });

  group('cached bulk deletion', () {
    test('deleteByAccountId removes only cached expenses for the account',
        () async {
      await seed(expense(id: 'account-1-a'));
      await seed(expense(id: 'account-1-b'));
      await seed(expense(id: 'account-2', account: 'account-2'));

      await provider.deleteByAccountId(accountId);

      final remaining = await firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .get();
      expect(remaining.docs.map((doc) => doc.id), ['account-2']);
    });

    test('deleteByCategoryId removes only cached expenses for the category',
        () async {
      await seed(expense(id: 'category-1-a'));
      await seed(expense(id: 'category-2', category: otherCategoryId));

      await provider.deleteByCategoryId(categoryId);

      final remaining = await firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .get();
      expect(remaining.docs.map((doc) => doc.id), ['category-2']);
    });
  });
}
