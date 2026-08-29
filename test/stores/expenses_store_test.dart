import 'package:budgly/src/stores/expenses.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ExpensesStore store;

  setUp(() {
    store = ExpensesStore.instance;
    store.clearAll();
  });

  Expense buildExpense({
    String id = 'exp-1',
    String accountId = 'account-1',
    String categoryId = 'cat-1',
    DateTime? debitDate,
    double amount = 10.0,
  }) {
    return Expense(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      name: 'Test',
      amount: amount,
      debitDate: debitDate ?? DateTime(2026, 6, 1),
    );
  }

  group('ExpensesStore.setExpensesForAccount', () {
    test('stores expenses sorted by debit date descending', () {
      final expenses = [
        buildExpense(id: 'e1', debitDate: DateTime(2026, 1, 1)),
        buildExpense(id: 'e2', debitDate: DateTime(2026, 6, 1)),
        buildExpense(id: 'e3', debitDate: DateTime(2026, 3, 1)),
      ];

      store.setExpensesForAccount('account-1', expenses);
      final result = store.getExpensesForAccount('account-1');

      expect(result[0].id, 'e2');
      expect(result[1].id, 'e3');
      expect(result[2].id, 'e1');
    });

    test('marks account as loaded', () {
      store.setExpensesForAccount('account-1', []);
      expect(store.hasLoadedAccount('account-1'), isTrue);
    });

    test('returns unmodifiable list', () {
      store.setExpensesForAccount('account-1', [buildExpense()]);
      final list = store.getExpensesForAccount('account-1');
      expect(() => list.add(buildExpense(id: 'e2')), throwsUnsupportedError);
    });
  });

  group('ExpensesStore.addExpense', () {
    test('adds expense to correct account', () {
      store.addExpense(buildExpense(id: 'e1', accountId: 'acc-1'));
      store.addExpense(buildExpense(id: 'e2', accountId: 'acc-2'));

      expect(store.getExpensesForAccount('acc-1'), hasLength(1));
      expect(store.getExpensesForAccount('acc-2'), hasLength(1));
    });

    test('maintains sort order after add', () {
      store.addExpense(buildExpense(id: 'e1', debitDate: DateTime(2026, 1, 1)));
      store.addExpense(buildExpense(id: 'e2', debitDate: DateTime(2026, 6, 1)));

      final list = store.getExpensesForAccount('account-1');
      expect(list[0].id, 'e2');
      expect(list[1].id, 'e1');
    });
  });

  group('ExpensesStore.getExpenseById', () {
    test('finds expense across all accounts', () {
      store.addExpense(buildExpense(id: 'e1', accountId: 'acc-1'));
      store.addExpense(buildExpense(id: 'e2', accountId: 'acc-2'));

      expect(store.getExpenseById('e2')?.accountId, 'acc-2');
    });

    test('returns null for nonexistent id', () {
      expect(store.getExpenseById('nonexistent'), isNull);
    });
  });

  group('ExpensesStore.updateExpense', () {
    test('moves expense to new account if changed', () {
      store.addExpense(buildExpense(id: 'e1', accountId: 'acc-1'));
      store.updateExpense(buildExpense(id: 'e1', accountId: 'acc-2'));

      expect(store.getExpensesForAccount('acc-1'), isEmpty);
      expect(store.getExpensesForAccount('acc-2'), hasLength(1));
    });

    test('updates expense in place when account is same', () {
      store.addExpense(buildExpense(id: 'e1', amount: 10));
      store.updateExpense(buildExpense(id: 'e1', amount: 20));

      final list = store.getExpensesForAccount('account-1');
      expect(list, hasLength(1));
      expect(list.first.amount, 20);
    });
  });

  group('ExpensesStore.replaceExpenseWithVersions', () {
    test('removes original from all accounts and adds both versions', () {
      store.addExpense(buildExpense(id: 'e1', accountId: 'acc-1'));

      final previous = buildExpense(id: 'e1', accountId: 'acc-1');
      final next = buildExpense(id: 'e1-new', accountId: 'acc-2');

      store.replaceExpenseWithVersions(previous: previous, next: next);

      expect(store.getExpensesForAccount('acc-1'), isEmpty);
      final acc2 = store.getExpensesForAccount('acc-2');
      expect(acc2, hasLength(2));
      expect(acc2.any((e) => e.id == 'e1'), isTrue);
      expect(acc2.any((e) => e.id == 'e1-new'), isTrue);
    });
  });

  group('ExpensesStore.removeExpense', () {
    test('removes expense from correct account', () {
      store.addExpense(buildExpense(id: 'e1', accountId: 'acc-1'));
      store.removeExpense('e1', 'acc-1');

      expect(store.getExpensesForAccount('acc-1'), isEmpty);
    });

    test('does not affect other accounts', () {
      store.addExpense(buildExpense(id: 'e1', accountId: 'acc-1'));
      store.addExpense(buildExpense(id: 'e2', accountId: 'acc-2'));
      store.removeExpense('e1', 'acc-1');

      expect(store.getExpensesForAccount('acc-2'), hasLength(1));
    });
  });

  group('ExpensesStore.clearAccountCache', () {
    test('removes account and its expenses', () {
      store.setExpensesForAccount('acc-1', [buildExpense()]);
      store.clearAccountCache('acc-1');

      expect(store.hasLoadedAccount('acc-1'), isFalse);
      expect(store.getExpensesForAccount('acc-1'), isEmpty);
    });
  });

  group('ExpensesStore.clearCategoryCache', () {
    test('removes expenses matching category', () {
      store.addExpense(buildExpense(id: 'e1', categoryId: 'cat-1'));
      store.addExpense(buildExpense(id: 'e2', categoryId: 'cat-2'));
      store.addExpense(buildExpense(id: 'e3', categoryId: 'cat-1'));

      store.clearCategoryCache('cat-1');

      final remaining = store.getExpensesForAccount('account-1');
      expect(remaining, hasLength(1));
      expect(remaining.first.categoryId, 'cat-2');
    });

    test('does not notify when nothing changed', () {
      store.addExpense(buildExpense(id: 'e1', categoryId: 'cat-1'));
      var notified = false;
      store.addListener(() => notified = true);

      store.clearCategoryCache('cat-999');
      expect(notified, isFalse);
    });
  });

  group('ExpensesStore.clearAll', () {
    test('clears everything', () {
      store.addExpense(buildExpense(id: 'e1', accountId: 'acc-1'));
      store.addExpense(buildExpense(id: 'e2', accountId: 'acc-2'));

      store.clearAll();

      expect(store.getExpensesForAccount('acc-1'), isEmpty);
      expect(store.getExpensesForAccount('acc-2'), isEmpty);
    });
  });

  group('ExpensesStore.listeners', () {
    test('notifies on add', () {
      var notified = false;
      store.addListener(() => notified = true);
      store.addExpense(buildExpense());
      expect(notified, isTrue);
    });


    test('notifies on update', () {
      store.addExpense(buildExpense(id: 'e1'));
      var notified = false;
      store.addListener(() => notified = true);
      store.updateExpense(buildExpense(id: 'e1', amount: 20));
      expect(notified, isTrue);
    });
  });
}
