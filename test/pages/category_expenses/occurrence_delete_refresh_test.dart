import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/pages/category_expenses/view_model.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';
import '../../helpers/fake_expense_firestore.dart';
import '../../helpers/fake_stores.dart';

void main() {
  final period = Fixtures.period(2026, 3);

  setUp(() {
    clearAllTestStores();
    Fixtures.resetSeq();
    seedAccounts([Fixtures.account(id: 'a1')]);
    seedCategories('a1', [Fixtures.category(id: 'c1', accountId: 'a1')]);
  });

  tearDown(clearAllTestStores);

  Expense monthly(String id, DateTime debitDate) => Expense(
        id: id,
        accountId: 'a1',
        categoryId: 'c1',
        name: 'Loyer',
        amount: 100,
        debitDate: debitDate,
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: debitDate.day,
      );

  test('delete single occurrence refreshes the occurrence list and total',
      () async {
    final firestore = RefreshAwareExpenseFirestore()
      ..serverExpenses.add(monthly('e1', DateTime(2026, 1, 15)));
    final expensesService = ExpensesService(expenseFirestore: firestore);
    addTearDown(expensesService.dispose);

    final vm = CategoryExpensesViewModel(
      accountId: 'a1',
      categoryId: 'c1',
      period: period,
      expensesService: expensesService,
    );
    addTearDown(vm.dispose);

    await vm.ensureDataLoaded();

    expect(vm.occurrences, hasLength(1));
    expect(vm.summary?.total, 100);

    final deletedOccurrence = vm.occurrences.single;
    expect(await vm.deleteSingleOccurrence(deletedOccurrence), isTrue);

    expect(vm.occurrences, isEmpty);
    expect(vm.summary?.total, 0);
  });

  test('delete future occurrences refreshes the occurrence list and total',
      () async {
    final firestore = RefreshAwareExpenseFirestore()
      ..serverExpenses.add(monthly('e1', DateTime(2026, 1, 15)));
    final expensesService = ExpensesService(expenseFirestore: firestore);
    addTearDown(expensesService.dispose);

    final vm = CategoryExpensesViewModel(
      accountId: 'a1',
      categoryId: 'c1',
      period: period,
      expensesService: expensesService,
    );
    addTearDown(vm.dispose);

    await vm.ensureDataLoaded();

    final deletedOccurrence = vm.occurrences.single;
    expect(await vm.deleteFutureOccurrences(deletedOccurrence), isTrue);

    expect(vm.occurrences, isEmpty);
    expect(vm.summary?.total, 0);
  });

  test('creating an expense reflects it in the occurrence list and total',
      () async {
    final firestore = RefreshAwareExpenseFirestore();
    final expensesService = ExpensesService(expenseFirestore: firestore);
    addTearDown(expensesService.dispose);

    await expensesService.createExpense(
      Expense(
        id: 'e1',
        accountId: 'a1',
        categoryId: 'c1',
        name: 'Courses',
        amount: 80,
        debitDate: DateTime(2026, 3, 12),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final vm = CategoryExpensesViewModel(
      accountId: 'a1',
      categoryId: 'c1',
      period: period,
      expensesService: expensesService,
    );
    addTearDown(vm.dispose);

    await vm.ensureDataLoaded();

    expect(vm.occurrences, hasLength(1));
    expect(vm.occurrences.single.expense.id, 'e1');
    expect(vm.occurrences.single.amount, 80);
    expect(vm.summary?.total, 80);
  });

  test('single occurrence modify refreshes the occurrence list and total',
      () async {
    final firestore = RefreshAwareExpenseFirestore()
      ..serverExpenses.add(monthly('e1', DateTime(2026, 1, 15)));
    final expensesService = ExpensesService(expenseFirestore: firestore);
    addTearDown(expensesService.dispose);

    final vm = CategoryExpensesViewModel(
      accountId: 'a1',
      categoryId: 'c1',
      period: period,
      expensesService: expensesService,
    );
    addTearDown(vm.dispose);

    await vm.ensureDataLoaded();

    vm.startEditing(vm.occurrences.single);
    vm.setRecurringEditScope(RecurringEditScope.single);
    vm.expenseForm.data.amountController.text = '250';

    expect(await vm.saveEditing(), isTrue);

    expect(vm.occurrences, hasLength(1));
    expect(vm.occurrences.single.amount, 250);
  });
}